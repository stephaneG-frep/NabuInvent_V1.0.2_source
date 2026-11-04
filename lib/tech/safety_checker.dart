import '../models/invention_project.dart';

/// Gravité d'un point de sécurité.
enum SafetyLevel {
  advice('Conseil'),
  warning('Attention'),

  /// Le projet demande l'avis ou l'intervention d'un professionnel.
  professional('Validation professionnelle');

  const SafetyLevel(this.label);
  final String label;
}

class SafetyFinding {
  final SafetyLevel level;
  final String topic;
  final String advice;

  const SafetyFinding(this.level, this.topic, this.advice);

  String get text => '$topic : $advice';
}

/// Contrôles de sécurité déterministes, à partir des matériaux, outils et
/// descriptions d'un projet. Ce sont des rappels : ils ne garantissent jamais
/// qu'un assemblage est sûr, et l'interface le dit.
class SafetyChecker {
  SafetyChecker._();

  static const disclaimer =
      'Rappels automatiques : ils ne remplacent pas une vérification sur place et ne garantissent '
      'pas la sécurité de l\'assemblage.';

  static String _norm(String s) {
    const from = 'àáâäãåçèéêëìíîïòóôöõùúûüýÿñœ';
    const to = 'aaaaaaceeeeiiiiooooouuuuyyno';
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    return b.toString();
  }

  static List<SafetyFinding> checkProject(InventionProject p) => check(
        materials: [...p.materials, ...?p.tech?.parts.map((e) => '${e.name} ${e.material}')],
        tools: p.tools,
        text: [
          p.title,
          p.problem,
          p.concept,
          p.mechanism,
          p.category,
          ...p.tags,
          for (final s in p.plan.steps) '${s.title} ${s.detail}',
        ].join(' '),
        maxDimensionMm: [
          for (final part in p.tech?.parts ?? const [])
            ...[part.length, part.width].whereType<double>(),
          for (final d in p.tech?.dimensions ?? const []) ?d.value,
        ].fold<double>(0, (a, b) => b > a ? b : a),
      );

  static List<SafetyFinding> check({
    List<String> materials = const [],
    List<String> tools = const [],
    String text = '',
    double maxDimensionMm = 0,
  }) {
    final mat = _norm(materials.join(' | '));
    final tool = _norm(tools.join(' | '));
    final all = '$mat | $tool | ${_norm(text)}';
    bool has(String pattern, [String? where]) => RegExp(pattern).hasMatch(where ?? all);

    final f = <SafetyFinding>[];

    final cans = has(r'conserve|canette');
    if (cans || has(r'tole|metal|alu|zinc|fer blanc|acier', mat)) {
      f.add(const SafetyFinding(SafetyLevel.warning, 'Bords coupants',
          'ébavure chaque découpe (lime, papier abrasif), porte des gants anti-coupure et protège '
              'les arêtes (bord replié, ruban, profilé caoutchouc).'));
    }
    if (cans || has(r'bidon|recipient|pot de peinture|jerrican')) {
      f.add(const SafetyFinding(SafetyLevel.warning, 'Récipients réutilisés',
          'n\'utilise que des récipients alimentaires lavés. Ne réutilise pas un récipient ayant '
              'contenu des solvants, carburants, pesticides ou produits chimiques sans procédure de '
              'nettoyage adaptée ; dans le doute, ne l\'utilise pas.'));
    }
    final outdoor = has(r'jardin|exterieur|balcon|terrasse|potager|pluie|cour\b');
    if (outdoor && (cans || has(r'acier|fer|metal|tole|vis|clou', mat))) {
      f.add(const SafetyFinding(SafetyLevel.advice, 'Corrosion',
          'à l\'extérieur, l\'acier rouille : préfère vis inox ou galvanisées et applique un '
              'antirouille puis une peinture extérieure.'));
    }
    if (outdoor && has(r'bois|planche|palette|tasseau|contreplaque', mat)) {
      f.add(const SafetyFinding(SafetyLevel.advice, 'Humidité',
          'traite le bois pour l\'extérieur, évite le contact direct avec le sol et prévois '
              'l\'écoulement de l\'eau.'));
    }
    if (outdoor && cans) {
      f.add(const SafetyFinding(SafetyLevel.advice, 'Eau stagnante',
          'perce le fond des contenants pour que l\'eau s\'évacue.'));
    }
    if (maxDimensionMm >= 1000 ||
        has(r'etagere|support|suspendu|hauteur|socle|piquet|mat\b|totem|colonne')) {
      f.add(const SafetyFinding(SafetyLevel.warning, 'Stabilité',
          'vérifie le risque de basculement : base large ou lestée, ancrage au sol ou au mur, et '
              'essai de charge progressif avant usage.'));
    }
    if (has(r'balancoire|chaise|siege|tabouret|echelle|escabeau|escalier|hamac|garde-corps|mezzanine|lit\b')) {
      f.add(const SafetyFinding(SafetyLevel.professional, 'Charge humaine',
          'un objet qui porte une personne doit être dimensionné et contrôlé par un professionnel '
              '(menuisier, bureau d\'études) avant utilisation.'));
    }
    if (has(r'230 ?v|secteur|prise electrique|tableau electrique|220 ?v')) {
      f.add(const SafetyFinding(SafetyLevel.professional, 'Électricité secteur',
          'tout montage sur le 230 V doit être réalisé ou validé par un électricien qualifié.'));
    } else if (has(r'electron|led|batterie|pile|arduino|moteur|cable|lithium|usb|interrupteur')) {
      f.add(const SafetyFinding(SafetyLevel.warning, 'Électricité',
          'travaille hors tension, isole les connexions, évite les courts-circuits et utilise des '
              'batteries lithium avec protection (BMS) et un chargeur adapté.'));
    }
    if (has(r'peinture|vernis|solvant|white.?spirit|epoxy|resine|colle forte|acide|javel|decapant|lasure')) {
      f.add(const SafetyFinding(SafetyLevel.warning, 'Produits chimiques',
          'aère bien, porte gants nitrile et masque adapté, ne mélange pas les produits et respecte '
              'les fiches de sécurité.'));
    }
    if (has(r'soud|chalumeau|brasure')) {
      f.add(const SafetyFinding(SafetyLevel.warning, 'Soudure',
          'protège yeux et peau, travaille ventilé, loin de tout matériau inflammable, avec un '
              'extincteur à portée.'));
    }
    if (has(r'disqueuse|meuleuse|scie sauteuse|scie circulaire|perceuse|defonceuse|ponceuse', tool) ||
        has(r'disqueuse|meuleuse')) {
      f.add(const SafetyFinding(SafetyLevel.advice, 'Outils électroportatifs',
          'lunettes et protection auditive, pièce bloquée dans un étau ou par des serre-joints, '
              'mains hors de l\'axe de coupe.'));
    }
    if (has(r'enfant|jouet|bebe|ludique|eveil')) {
      f.add(const SafetyFinding(SafetyLevel.warning, 'Enfants',
          'aucune petite pièce détachable pour les moins de 3 ans, aucune arête vive, peintures et '
              'vernis adaptés aux jouets.'));
    }
    return f;
  }
}
