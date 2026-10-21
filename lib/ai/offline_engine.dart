import 'dart:convert';
import 'dart:math';

import '../models/idea_evaluation.dart';
import '../models/invention_project.dart';
import '../models/json_utils.dart';
import 'ai_provider.dart';
import 'ai_response.dart';

class InvBase {
  final String title;
  final String problem;
  final String concept;
  final String mechanism;
  final List<String> materials;
  final List<String> tools;
  final String budget;
  final int difficulty;
  final String time;
  final String category;
  final List<String> tags;

  const InvBase({
    required this.title,
    this.problem = '',
    this.concept = '',
    this.mechanism = '',
    this.materials = const [],
    this.tools = const [],
    this.budget = '',
    this.difficulty = 2,
    this.time = '',
    this.category = '',
    this.tags = const [],
  });
}

class DomainEntry {
  final String name;
  final List<String> keywords;
  final List<InvBase> inventions;
  final List<Map<String, String>> stepTemplates;

  const DomainEntry({
    required this.name,
    required this.keywords,
    required this.inventions,
    this.stepTemplates = const [],
  });
}

class SparkSource {
  final String domain;
  final String mechanism;
  final String material;
  final String pitch;
  const SparkSource({
    required this.domain,
    required this.mechanism,
    required this.material,
    required this.pitch,
  });
}

class OfflineEngine extends AiProvider {
  static final Random _rng = Random();

  @override
  String get name => 'Atelier local';

  @override
  bool get isCloud => false;

  @override
  bool get isConfigured => true;

  @override
  Future<NabuAiResponse> respond({
    required String userText,
    List<AiTurn> history = const [],
    String? projectContext,
  }) async {
    final text = stripAccents(userText.trim().toLowerCase());
    final ctx = _parseContext(projectContext);

    if (text.isEmpty) {
      return _menu('Décris-moi un problème, un besoin ou une idée, et je me mets à inventer !');
    }
    // Une salutation seule affiche le menu ; « Bonjour, invente-moi… » continue.
    if (_matchesAny(text, _greetings) && _withoutGreetings(text).length < 6) {
      return _menu(
        'Salut ! Je suis NabuInvent, ton agent inventeur. Je peux générer une invention, '
        'construire un plan pas à pas, évaluer une idée, lancer des étincelles créatives, '
        'ou noter une pensée dans ton journal. Que veux-tu inventer aujourd\'hui ?',
      );
    }
    if (text.length < 6) {
      return _menu('Donne-moi un peu plus de matière : quel problème veux-tu résoudre ?');
    }

    // Un message qui commence par « invente / conçois / imagine » demande une
    // invention, même s'il cite ensuite une étincelle, un défi ou un plan.
    if (RegExp('^(?:${_inventVerbs.map(RegExp.escape).join('|')})(?![a-z0-9])')
        .hasMatch(_withoutGreetings(text))) {
      return _invent(userText.trim(), text, ctx);
    }
    if (_matchesAny(text, _journalWords)) {
      return _journal(text);
    }
    if (_matchesAny(text, _sparkWords)) {
      return _spark();
    }
    if (_matchesAny(text, _evalWords)) {
      return _evaluate(userText.trim());
    }
    if (_matchesAny(text, _planWords)) {
      return _plan(text, ctx);
    }
    if (_matchesAny(text, _explainWords)) {
      return _explain();
    }
    return _invent(userText.trim(), text, ctx);
  }

  static final List<DomainEntry> _domains = _buildDomains();
  // Mots-clés d'intention, sans accents (le texte est désaccentué avant
  // comparaison) et comparés comme mots entiers (pluriel en -s/-x accepté) :
  // « plan » ne doit pas reconnaître « plantes » ni « planche ».
  static final List<String> _greetings = [
    'salut', 'bonjour', 'hello', 'coucou', 'bonsoir', 'yo', 'ca va', 'salve',
  ];
  static final List<String> _inventVerbs = [
    'invente', 'inventes', 'concois', 'imagine', 'cree-moi', 'trouve-moi',
  ];
  static final List<String> _planWords = [
    'plan', 'etape', 'construis', 'comment le faire', 'comment faire',
    'comment construire', 'fabriquer', 'fabrication', 'pas a pas',
    'mode d\'emploi', 'mode emploi', 'montage', 'assemble', 'assembler',
    'assemblage', 'prototype',
  ];
  static final List<String> _evalWords = [
    'evalue', 'evaluer', 'evaluation', 'evalue-la', 'evalue-le', 'viable',
    'est-ce une bonne', 'est ce une bonne', 'analyse', 'analyser',
    'note cette idee', 'faisabilite', 'bonne ou pas', 'vaut le coup',
    'bon investissement',
  ];
  static final List<String> _sparkWords = [
    'etincelle', 'spark', 'defi', 'challenge', 'aleatoire', 'au hasard',
    'bizarre', 'improvise', 'surprends', 'surprends-moi', 'stretch', 'impossible',
  ];
  static final List<String> _journalWords = [
    'note dans mon journal', 'journal', 'ecris une note', 'memo',
    'note pour plus tard', 'retiens', 'souviens', 'souvenir',
  ];
  static final List<String> _explainWords = [
    'explique', 'explique-moi', 'comment ca marche', 'pourquoi', 'a quoi ca sert',
  ];

  static final Map<String, RegExp> _wordPatterns = {};

  RegExp _wordPattern(String w) => _wordPatterns.putIfAbsent(
        w,
        () => RegExp('(?<![a-z0-9])${RegExp.escape(w)}(?:s|x)?(?![a-z0-9])'),
      );

  bool _matchesAny(String text, List<String> words) =>
      words.any((w) => _wordPattern(w).hasMatch(text));

  String _withoutGreetings(String text) {
    var rest = text;
    for (final g in _greetings) {
      rest = rest.replaceAll(_wordPattern(g), ' ');
    }
    return rest.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  // Mots-clés de domaine : ce sont souvent des radicaux (« arros », « nettoy »),
  // on exige seulement qu'ils commencent un mot (« sol » ≠ « console »).
  static final Map<String, RegExp> _stemPatterns = {};

  bool _matchesStem(String text, String keyword) => _stemPatterns
      .putIfAbsent(
        keyword,
        () => RegExp('(?<![a-z0-9])${RegExp.escape(stripAccents(keyword))}'),
      )
      .hasMatch(text);

  String stripAccents(String s) {
    const from = 'àáâäãåçèéêëìíîïòóôöõùúûüýÿñ';
    const to = 'aaaaaaceeeeiiiiooooouuuuyyn';
    final buf = StringBuffer();
    for (final ch in s.split('')) {
      final i = from.indexOf(ch);
      buf.write(i >= 0 ? to[i] : ch);
    }
    return buf.toString();
  }

  _Ctx _parseContext(String? ctx) {
    if (ctx == null || ctx.isEmpty) return _Ctx.empty;
    try {
      final json = jsonDecode(ctx) as Map<String, dynamic>;
      return _Ctx(
        title: jsonString(json['title']),
        problem: jsonString(json['problem']),
        id: jsonString(json['id']),
        category: jsonString(json['category']),
        concept: jsonString(json['concept']),
        mechanism: jsonString(json['mechanism']),
        materials: jsonStringList(json['materials']),
        tools: jsonStringList(json['tools']),
        budget: jsonString(json['budget']),
        time: jsonString(json['timeEstimate']),
        difficulty: json['difficulty'] == null
            ? null
            : jsonInt(json['difficulty'], 2, min: 1, max: 5),
        tags: jsonStringList(json['tags']),
      );
    } catch (_) {
      return _Ctx.empty;
    }
  }

  NabuAiResponse _menu(String msg) => NabuAiResponse(
        provider: name,
        message: msg,
        intent: AiIntent.none,
      );

  _Match _findDomain(String text) {
    DomainEntry? matched;
    InvBase? base;
    for (final d in _domains) {
      if (d.keywords.any((k) => _matchesStem(text, k))) {
        matched = d;
        break;
      }
    }
    if (matched != null) {
      base = matched.inventions[_rng.nextInt(matched.inventions.length)];
    }
    return _Match(domain: matched, base: base);
  }

  NabuAiResponse _invent(String raw, String text, _Ctx ctx) {
    final m = _findDomain(text);
    final InvBase base;

    if (m.base != null && ctx.title.isEmpty) {
      base = m.base!;
    } else if (m.base != null) {
      base = m.base!;
    } else {
      base = _genericInvention();
    }

    final mention = _mentionProblem(raw, base.problem);
    // Une invention est toujours un nouveau projet : réutiliser l'id du projet
    // en cours l'écraserait (plan, progression, statut perdus).
    final project = InventionProject(
      id: 'new',
      title: base.title,
      problem: base.problem,
      subtitle: mention,
      concept: base.concept.isEmpty
          ? 'Concept inventé pour répondre au besoin exprimé. ${base.mechanism}'
          : base.concept,
      mechanism: base.mechanism,
      materials: List.of(base.materials),
      tools: List.of(base.tools),
      budget: base.budget,
      timeEstimate: base.time,
      difficulty: base.difficulty,
      category: base.category,
      score: 62 + _rng.nextInt(25),
      tags: List.of(base.tags),
    );

    final msg = 'Voici : « ${base.title} ». '
        '${_mentionProblem(raw, base.problem)} '
        '${base.mechanism} J\'ai réuni les matériaux, l\'outillage et une estimation de coût. '
        'Dis-moi « élabore le plan » pour les étapes de construction, ou « évalue cette idée » pour mon avis de pro.';

    return NabuAiResponse(
      provider: name,
      message: msg,
      intent: AiIntent.invent,
      project: project,
      journalText: 'Nouvelle invention imaginée : ${base.title}.',
    );
  }

  String _mentionProblem(String raw, String fallback) {
    final problem = raw.trim();
    if (problem.length < 10) return fallback;
    final shortened = problem.length > 140 ? '${problem.substring(0, 137)}…' : problem;
    return 'Partant de ton besoin (« $shortened »), voici une piste d\'invention.';
  }

  InvBase _genericInvention() {
    final d = _domains[_rng.nextInt(_domains.length)];
    return d.inventions[_rng.nextInt(d.inventions.length)];
  }

  NabuAiResponse _plan(String text, _Ctx ctx) {
    final m = _findDomain(text);
    final domain = m.domain;
    final base = m.base ?? _genericInvention();

    // Avec un projet en cours, le plan porte sur CE projet : on garde ses
    // champs et on ne complète qu'avec ceux du modèle de domaine.
    final inv = ctx.title.isNotEmpty
        ? InvBase(
            title: ctx.title,
            problem: ctx.problem,
            concept: ctx.concept,
            mechanism: ctx.mechanism,
            category: ctx.category.isNotEmpty ? ctx.category : base.category,
            materials: ctx.materials.isNotEmpty ? ctx.materials : base.materials,
            tools: ctx.tools.isNotEmpty ? ctx.tools : base.tools,
            budget: ctx.budget.isNotEmpty ? ctx.budget : base.budget,
            difficulty: ctx.difficulty ?? base.difficulty,
            time: ctx.time.isNotEmpty ? ctx.time : base.time,
            tags: ctx.tags,
          )
        : base;

    final steps = _buildSteps(domain, inv);
    final stars = '★' * inv.difficulty;
    final dots = '☆' * (5 - inv.difficulty);
    final plan = ProjectPlan(
      notes: 'Plan de construction généré pour « ${inv.title} ». '
          'Avance étape par étape et coche chaque étape terminée. '
          'Lis les consignes de sécurité avant de commencer.',
      duration: inv.time.isNotEmpty ? inv.time : '3-4 h',
      budget: inv.budget.isNotEmpty ? inv.budget : '≈ 15-25 € de matériaux',
      difficulty: 'Difficulté : $stars$dots',
      steps: steps,
    );

    final project = InventionProject(
      id: ctx.id.isNotEmpty ? ctx.id : 'new',
      title: inv.title,
      problem: inv.problem,
      concept: inv.concept,
      mechanism: inv.mechanism,
      materials: List.of(inv.materials),
      tools: List.of(inv.tools),
      budget: inv.budget,
      timeEstimate: inv.time,
      difficulty: inv.difficulty,
      category: inv.category,
      score: 65 + _rng.nextInt(20),
      tags: List.of(inv.tags),
      status: ProjectStatus.plan,
      plan: plan,
    );

    return NabuAiResponse(
      provider: name,
      message:
          'J\'ai échafaudé un plan en ${steps.length} étapes pour « ${inv.title} ». '
          'Étapes : ${steps.length}, budget ${plan.budget}, durées détaillées dans le plan. '
          'Dit-moi « lance la construction » quand tu démarres, ou « note dans mon journal » pour garder une trace.',
      intent: AiIntent.plan,
      project: project,
      plan: plan,
      journalText: 'Plan de construction de « ${inv.title} » élaboré (${steps.length} étapes).',
    );
  }

  List<PlanStep> _buildSteps(DomainEntry? domain, InvBase inv) {
    final tpls = domain?.stepTemplates.isNotEmpty == true
        ? domain!.stepTemplates
        : _genericStepTemplates;
    final steps = <PlanStep>[];
    var i = 0;
    for (final t in tpls.take(4)) {
      i++;
      steps.add(_step(t, i, inv));
    }
    steps.add(_step(const {
      'title': 'Prototype rapide',
      'detail': 'Assemble une première version avec du bricolage : fixation légère, collage, '
          'ruban adhésif ou vis provisoires. L\'objectif est de valider le fonctionnement avant le travail fini.',
      'safety': 'Porte des lunettes de protection et travaille dans un espace ventilé.',
      'duration': '45 min',
    }, 5, inv));
    steps.add(_step(const {
      'title': 'Tests et ajustements',
      'detail': 'Utilise l\'invention en conditions réelles, repère les faiblesses (fixations, usure, ergonomie) '
          'et corrige une chose à la fois. Note les résultats dans ton journal de création.',
      'safety': 'Manipule prudemment les prototypes qui peuvent être fragiles.',
      'duration': '1 h 30',
    }, 6, inv));
    steps.add(_step(const {
      'title': 'Finitions et nettoyage',
      'detail': 'Renforce les jonctions, ponce ou nettoie, range les outils et trie les chutes. '
          'Prends une photo du résultat et coche cette étape : ton invention est née !',
      'safety': '',
      'duration': '30 min',
    }, 7, inv));
    return steps;
  }

  PlanStep _step(Map<String, String> t, int idx, InvBase inv) {
    final materials = idx <= 4 ? List.of(inv.materials).take(3).toList() : <String>[];
    return PlanStep(
      id: 'step_$idx',
      title: t['title'] ?? 'Étape $idx',
      detail: t['detail'] ?? '',
      duration: t['duration'] ?? '30 min',
      safety: t['safety'] ?? '',
      materials: materials,
      tools: idx <= 4 ? List.of(inv.tools).take(2).toList() : <String>[],
    );
  }

  static const List<Map<String, String>> _genericStepTemplates = [
    {
      'title': 'Rassemble les matériaux et l\'outillage',
      'detail': 'Fais l\'inventaire de ce que tu as déjà, achète le reste en petit budget ou récupère des chutes. '
          'Protège ta surface de travail.',
      'safety': '',
      'duration': '20 min',
    },
    {
      'title': 'Prépare et mesure',
      'detail': 'Trace tes mesures au crayon ou à la craie, découpe les morceaux aux dimensions et pré-fore les trous.',
      'safety': 'Découpe loin des mains, sur un support stable.',
      'duration': '45 min',
    },
    {
      'title': 'Assemblage principal',
      'detail': 'Assemble les pièces principales selon le principe retenu : vissage, collage ou clipsage.',
      'safety': 'Respecte les temps de séchage des colles et serre sans forcer.',
      'duration': '1 h',
    },
    {
      'title': 'Équipement et réglages',
      'detail': 'Installe les accessoires, règle les tensions et vérifie les jeux.',
      'safety': '',
      'duration': '30 min',
    },
  ];

  NabuAiResponse _evaluate(String raw) {
    final idea = raw.trim();
    final len = idea.length;
    final hash = idea.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
    final r2 = Random(hash);

    final hasRecycled = _matchesAny(stripAccents(idea.toLowerCase()), [
      'recycl', 'récup', 'recup', 'chute', 'palette', 'bouteille', 'carton', 'invendu',
    ]);
    final hasTech = _matchesAny(stripAccents(idea.toLowerCase()), [
      'capteur', 'arduino', 'servo', 'moteur', 'batterie', 'solaire', 'pomp', 'électro',
    ]);
    final hasSimple = _matchesAny(stripAccents(idea.toLowerCase()), [
      'simple', 'léger', 'leger', 'rapide', 'poignée', 'pince', 'ressort',
    ]);
    final hasBig = _matchesAny(stripAccents(idea.toLowerCase()), [
      'électri', 'electri', 'métal', 'metal', 'moteur', 'pression', 'haute température',
    ]);

    int clamp(int v) => v.clamp(0, 100);

    final originality = clamp(55 + r2.nextInt(30) + (hasRecycled ? 8 : 0) + (len > 120 ? 5 : 0));
    final feasibility = clamp(52 + r2.nextInt(26) + (hasSimple ? 10 : 0) - (hasBig ? 18 : 0));
    final cost = clamp(30 + (len ~/ 6) + r2.nextInt(30) + (hasRecycled ? -8 : 0) + (hasTech ? 15 : 0));
    final effort = clamp(30 + (len ~/ 5) + r2.nextInt(20) + (hasTech ? 12 : 0));
    final impact = clamp(50 + r2.nextInt(32) + (hasRecycled ? 6 : 0));

    final verdict = _verdict((originality + feasibility + impact) ~/ 3);
    final costLabel = cost < 35
        ? 'budget serré'
        : cost < 60
            ? 'budget moyen'
            : 'budget confortable';

    final strengths = <String>[
      hasRecycled
          ? 'Valorise des matériaux de récupération, donc économe et écolo.'
          : 'Idée porteuse de valeur d\'usage claire et compréhensible.',
      hasSimple
          ? 'Approche simple à prototyper, idéale pour une première version.'
          : hasTech
              ? 'La partie technique apporte un vrai plus différenciant.'
              : 'L\'angle est assez original dans le domaine où il s\'inscrit.',
      'Se prête bien à un prototype de week-end.',
    ];
    final risks = <String>[
      hasBig
          ? 'La partie technique (électricité/moteur) demande des précautions et des compétences spécifiques.'
          : 'Le temps de fabrication est souvent sous-estimé : prévois 20 % de marge.',
      'La robustesse des fixations de bricolage devra être vérifiée en usage réel.',
    ];
    final nextSteps = <String>[
      'Dessine un croquis simple du mécanisme.',
      'Prototype la jonction la plus fragile en premier.',
      if (cost >= 55) 'Compare 3 fournisseurs de matériaux pour serrer le budget.',
      'Note une liste des 3 risques principaux et leur parade.',
    ];

    final pitch =
        'En une phrase : $idea → inventer un objet $costLabel, réalisable en '
        'quelques heures, dont la valeur se situe dans la résolution du besoin quotidien '
        'plus que dans la technologie.';

    return NabuAiResponse(
      provider: name,
      message: 'Analyse terminée ! Score global ${(originality + feasibility + impact) ~/ 3}/100. '
          'Mon verdict : $verdict. Détail des critères dans la fiche.',
      intent: AiIntent.evaluate,
      evaluation: IdeaEvaluation(
        idea: idea,
        originality: originality,
        feasibility: feasibility,
        cost: cost,
        effort: effort,
        impact: impact,
        verdict: verdict,
        pitch: pitch,
        strengths: strengths,
        risks: risks,
        nextSteps: nextSteps,
      ),
    );
  }

  String _verdict(int overall) {
    if (overall >= 75) return 'Excellent — correspond à un vrai besoin et reste faisable. Lance un prototype !';
    if (overall >= 60) return 'Prometteur — mérite un prototype rapide pour valider le principe.';
    if (overall >= 45) return 'Correct — à affiner : simplifie le mécanisme et vise une version minimale.';
    return 'Fragile — le besoin ou le principe mérite d\'être creusé. Essaie de le détourner.';
  }

  NabuAiResponse _spark() {
    final r = _rng;
    final src = _sparkPool[r.nextInt(_sparkPool.length)];
    final challenge = r.nextBool();
    final title = _sparkTitle(src, challenge);
    final pitch = challenge
        ? 'Défi créatif : invente « $title » --- ${src.pitch} '
            'Contrainte imposée : $title.'
        : 'Étincelle : $title --- ${src.pitch}';

    return NabuAiResponse(
      provider: name,
      message: pitch,
      intent: AiIntent.spark,
      spark: SparkContent(
        title: title,
        domain: src.domain,
        mechanism: src.mechanism,
        material: src.material,
        pitch: pitch,
        challenge: challenge,
      ),
      journalText: 'Étincelle créative capturée : $title.',
    );
  }

  String _sparkTitle(SparkSource src, bool challenge) {
    const prefixes = ['Le', 'La', 'L\'', 'Un', 'Une'];
    if (challenge) {
      const c = ['Contrat : 3 objets', 'Contre-la-montre', '100 % récupération', 'Sans colle ni vis',
          'Énergie zéro', 'Taille de poche', 'Se construit seul'];
      return '${c[_rng.nextInt(c.length)]} — ${src.domain} vibrant';
    }
    final p = prefixes[_rng.nextInt(prefixes.length)];
    return '$p ${src.material} ${src.mechanism}';
  }

  static final List<SparkSource> _sparkPool = [
    const SparkSource(
      domain: 'maison',
      mechanism: 'gravité',
      material: 'bouteille plastique',
      pitch: 'Utilise la gravité pour créer un distributeur doseur sans électricité.',
    ),
    const SparkSource(
      domain: 'jardin',
      mechanism: 'capillarité',
      material: 'mèche en coton',
      pitch: 'Invente un arroseur permanent grâce à la remontée capillaire de la mèche.',
    ),
    const SparkSource(
      domain: 'énergie',
      mechanism: 'effet de serre',
      material: 'canette aluminium',
      pitch: 'Dompte l\'effet de serre d\'une canette pour réchauffer ou refroidir.',
    ),
    const SparkSource(
      domain: 'jeux',
      mechanism: 'balancier',
      material: 'pince à linge',
      pitch: 'Un petit automate balancier qui s\'anime avec le simple souffle.',
    ),
    const SparkSource(
      domain: 'électronique',
      mechanism: 'boucle de réaction',
      material: 'vieux câble USB',
      pitch: 'Réutilise un câble USB pour alimenter un capteur de présence maison.',
    ),
    const SparkSource(
      domain: 'cuisine',
      mechanism: 'levier',
      material: 'bouchon de liège',
      pitch: 'Un levier en liège qui transforme l\'ouverture d\'un pot en jeu d\'enfant.',
    ),
    const SparkSource(
      domain: 'atelier',
      mechanism: 'came',
      material: 'règle en métal',
      pitch: 'Une came maison qui transforme une rotation manuelle en mouvement régulier.',
    ),
    const SparkSource(
      domain: 'bureau',
      mechanism: 'équilibre',
      material: 'trombone',
      pitch: 'Des supports en trombone, un équilibre calculé, un organiseur qui flotte.',
    ),
    const SparkSource(
      domain: 'atelier bois',
      mechanism: 'épaulement',
      material: 'chute de contreplaqué',
      pitch: 'Un gabarit d\'assemblage par épaulement taillé dans une chute.',
    ),
    const SparkSource(
      domain: 'mobilité',
      mechanism: 'compression',
      material: 'chambre à air',
      pitch: 'Des tendeurs élastiques en chambre à air pour fixer du chargement.',
    ),
    const SparkSource(
      domain: 'bien-être',
      mechanism: 'thermique',
      material: 'sachet de graines',
      pitch: 'Une bouillote sèche en sachet de graines, chauffée sans eau ni électricité.',
    ),
    const SparkSource(
      domain: 'récupération',
      mechanism: 'pliage',
      material: 'carton ondulé',
      pitch: 'Une structure porteuse en carton plié, étonnamment résistante.',
    ),
  ];

  NabuAiResponse _journal(String raw) {
    final note = raw.trim();
    return NabuAiResponse(
      provider: name,
      message: 'Noté dans ton journal de création. Relis ces pensées plus tard : elles '
          'sont souvent le point de départ d\'une invention.',
      intent: AiIntent.journal,
      journalText: note.length > 240 ? '${note.substring(0, 237)}…' : note,
    );
  }

  NabuAiResponse _explain() {
    const text = 'Tout le métier d\'inventeur tient en trois boucles : '
        '1) Repérer un besoin (une friction quotidienne), '
        '2) Prototyper vite et mal plutôt que tard et parfait, '
        '3) Tester en usage réel puis itérer. '
        'Mon rôle : te donner des concepts, des plans pas à pas, et des évaluations honnêtes.';
    return NabuAiResponse(provider: name, message: text, intent: AiIntent.explain);
  }

  static List<DomainEntry> _buildDomains() => _domainsList;

  static final List<DomainEntry> _domainsList = [
    const DomainEntry(
      name: 'maison',
      keywords: ['maison', 'ménage', 'menage', 'nettoy', 'entretien', 'aspirateur',
          'poussière', 'poussiere', 'salon', 'sol', 'vitre', 'éponge', 'eponge', 'chambre'],
      inventions: [
        InvBase(
          title: 'Le Garde-Poussière',
          problem: 'Les poussières s\'accumulent dans les coins et sur les étagères.',
          concept: 'Un balai-lame en silicone biseauté qui canalise la poussière des angles '
              'vers la pelle sans en soulever, grâce à une brosse de guidage rétractable.',
          mechanism: 'La lame biseautée en silicone épouse les angles ; une brosse latérale '
              'retient les miettes pendant le trajet jusqu\'au bac.',
          materials: ['lame silicone de 50 cm', 'profilé PVC', 'pelle à poussière', 'pression à clic', 'ruban mousse'],
          tools: ['scie à métaux', 'perceuse', 'mètre', 'tournevis'],
          budget: '≈ 12 €',
          difficulty: 2,
          time: '2-3 h',
          category: 'Maison',
          tags: ['nettoyage', 'bricolage', 'zéro énergie'],
        ),
        InvBase(
          title: 'Le Distri-Dose',
          problem: 'On gaspille de la lessive ou de la soupe en dosant « à vue ».',
          concept: 'Un doseur à gravité intégré au goulot : un entonnoir gradué et un clapet '
              'en silicone qui libère une dose exacte à chaque basculement.',
          mechanism: 'La bascule du contenant fait coulisser un clapet lesté ; le volume '
              'utile est calibré par une bague graduée réglable.',
          materials: ['grande bouteille', 'goulot à visser', 'clapet silicone', 'bague graduée', 'tube en PVC rigide'],
          tools: ['colle époxy', 'cutters', 'perceuse', 'papier de verre'],
          budget: '≈ 10-14 €',
          difficulty: 2,
          time: '2 h',
          category: 'Maison',
          tags: ['économie', 'zéro gaspillage', 'cuisine'],
        ),
        InvBase(
          title: 'Le Sec-Express',
          problem: 'Le linge ne sèche pas assez vite en hiver, dans les petits espaces.',
          concept: 'Un séchoir d\'appoint qui combine un support pliant et une circulation '
              'd\'air passive : ailettes orientables qui canalisent l\'air vers les vêtements.',
          mechanism: 'Des ailettes réglables en carton rigide créent un appel d\'air '
              'naturel au-dessus des pièces humides, accélérant l\'évaporation.',
          materials: ['support en bois 60 cm', 'charnières', 'panneaux en polypropylène', 'treillis séchant', 'boulons à œil'],
          tools: ['scie sauteuse', 'perceuse', 'ponceuse', 'tournevis'],
          budget: '≈ 20 €',
          difficulty: 3,
          time: '4-5 h',
          category: 'Maison',
          tags: ['séchage', 'ventilation', 'économe'],
        ),
      ],
      stepTemplates: [
        {'title': 'Récolter et préparer le matériau principal', 'detail': 'Nettoie, dégraisse et ponce les surfaces : le silicone et les plastiques se collent mal sur un support gras.', 'safety': '', 'duration': '25 min'},
        {'title': 'Tracer et couper les pièces', 'detail': 'Reproduis le gabarit au crayon, découpe au cutter/dremel et vérifie les ajustements à blanc.', 'safety': 'Travaille sur un tapis de découpe, lame dirigée vers l\'extérieur.', 'duration': '1 h'},
        {'title': 'Coller ou visser l\'assemblage principal', 'detail': 'Applique la colle époxy en couche fine, maintiens 24 h avec des serre-joints, ou visse sur les points de jonction.', 'safety': 'Colle époxy : porte des gants et ventile la pièce.', 'duration': '1 h 30'},
        {'title': 'Intégrer le mécanisme (clapet/ailette/brosse)', 'detail': 'Monte l\'élément mobile, vérifie sa course et sa tension ; lubrifie si besoin.', 'safety': '', 'duration': '45 min'},
      ],
    ),
    const DomainEntry(
      name: 'jardin',
      keywords: ['jardin', 'plante', 'arros', 'serre', 'potager', 'compost', 'graine',
          'balcon', 'terre', 'semis', 'ruche', 'récolte', 'recolte', 'brumis', 'parasol'],
      inventions: [
        InvBase(
          title: 'La Carafe Goutte-à-Goutte',
          problem: 'On oublie d\'arroser les plantes, ou on les noie pendant les absences.',
          concept: 'Un réservoir d\'eau en bouteille inversée, relié à une mèche en coton '
              'qui diffuse l\'humidité à un rythme régulier dans la terre.',
          mechanism: 'La capillarité de la mèche tire l\'eau du réservoir vers le sol '
              'au fur et à mesure du séchage, régulant l\'humidité.',
          materials: ['grande bouteille', 'mèche en coton', 'couteau', 'baguette de terre cuite', 'grillage'],
          tools: ['cutter', 'ciseaux', 'perceuse fine'],
          budget: '≈ 3-5 €',
          difficulty: 1,
          time: '1 h',
          category: 'Jardin',
          tags: ['arrosage', 'autonomie', 'zéro déchet'],
        ),
        InvBase(
          title: 'La Mini-Serre d\'Appoint',
          problem: 'Les semis de printemps gèlent dehors ou souffrent de lumière inégale.',
          concept: 'Une serre-cloche bricolée en bouteilles transparentes empilées, avec '
              'un volet d\'aération coulissant pour contrôler température et hygrométrie.',
          mechanism: 'L\'effet de serre chauffe l\'air ; le volet supérieur crée une '
              'cheminée d\'air chaud, évitant la condensation excessive.',
          materials: ['bouteilles PET transparentes', 'fil de fer', 'volet en plexi', 'piquets', 'bande réfléchissante'],
          tools: ['cutter', 'perceuse', 'pince', 'mètre'],
          budget: '≈ 8 €',
          difficulty: 2,
          time: '2-3 h',
          category: 'Jardin',
          tags: ['serre', 'semis', 'récupération'],
        ),
        InvBase(
          title: 'Le Puise-Rosée',
          problem: 'Récupérer l\'eau de pluie et la rosée pour arroser sans gaspillage.',
          concept: 'Une toile inclinée qui collecte la rosée et les pluies fines, guidée '
              'par des rigoles vers un bidon fermé avec filtre anti-moustiques.',
          mechanism: 'La gravité et la tension de surface font couler l\'eau le long de '
              'la toile jusqu\'au collecteur.',
          materials: ['bâche 3 x 3 m', 'arceaux en PVC', 'bidon 30 L', 'tulle moustiquaire', 'sangles'],
          tools: ['scie', 'perceuse', 'marteau', 'piquets'],
          budget: '≈ 15 €',
          difficulty: 2,
          time: '3 h',
          category: 'Jardin',
          tags: ['eau de pluie', 'autonomie', 'climat'],
        ),
      ],
      stepTemplates: [
        {'title': 'Préparer le support et les fixations', 'detail': 'Nettoie les récupérations, perce les points de fixation et prépare les arceaux.', 'safety': 'Ponce les bords de coupe pour éviter les échardes.', 'duration': '30 min'},
        {'title': 'Installer la structure porteuse', 'detail': 'Fixe les arceaux ou le cadre au sol/tuteur, vérifie la stabilité.', 'safety': '', 'duration': '45 min'},
        {'title': 'Poser et tendre la toile/la membrane', 'detail': 'Dispose la surface collectrice avec une pente douce vers le récupérateur, scelle les jonctions.', 'safety': '', 'duration': '1 h'},
        {'title': 'Brancher la conduite et le filtre', 'detail': 'Raccorde les rigoles au collecteur et pose le filtre anti-insectes sur l\'entrée.', 'safety': '', 'duration': '30 min'},
      ],
    ),
    const DomainEntry(
      name: 'cuisine',
      keywords: ['cuisine', 'cuisiner', 'gadget', 'conserve', 'couverts', 'four', 'couteau',
          'épluche', 'epluche', 'batteur', 'gâteau', 'gateau', 'herbe', 'épices', 'epices', 'dessert'],
      inventions: [
        InvBase(
          title: 'Le Coup-de-Pouce ouvre-pot',
          problem: 'Les couvercles de bocaux sont trop durs à ouvrir pour tous les publics.',
          concept: 'Une poignée-levier à friction réglable qui s\'agrippe au couvercle et '
              'multiplie la force de la main sans électricité.',
          mechanism: 'Le levier démultiplie la force et une bande adhésive antidérapante '
              'évite le glissement ; le diamètre s\'adapte aux bocaux.',
          materials: ['poignée bois', 'charnière métallique', 'bande caoutchouc', 'boulons', 'manchon silicone'],
          tools: ['perceuse', 'lime', 'tournevis', 'scie'],
          budget: '≈ 6-9 €',
          difficulty: 1,
          time: '1 h 30',
          category: 'Cuisine',
          tags: ['accessibilité', 'ergonomie', 'bricolage'],
        ),
        InvBase(
          title: 'Le Trieur d\'Herbes aromatiques',
          problem: 'On récolte des herbes et on perd du temps à les trier des mauvaises tiges.',
          concept: 'Un râteau-découpeur en forme de peigne qui effeuille en une passe et '
              'un panier de tri à double fond qui sépare les feuilles des tiges.',
          mechanism: 'Les dents du peigne glissent le long des tiges ; les feuilles '
              'tombent au travers de la grille du panier.',
          materials: ['planchette', 'épingles métalliques', 'grille fine', 'clous', 'mèche'],
          tools: ['scie', 'pince', 'perceuse', 'marteau'],
          budget: '≈ 5 €',
          difficulty: 1,
          time: '1 h',
          category: 'Cuisine',
          tags: ['récolte', 'gain de temps', 'récup'],
        ),
        InvBase(
          title: 'Le Four Solaire de Poche',
          problem: 'Réduire la consommation du four pour les petites cuissons.',
          concept: 'Un four solaire pliant de 50 cm qui concentre les rayons sur un '
              'récipient sombre, pour griller ou réchauffer en plein air.',
          mechanism: 'Des panneaux réfléchissants concentrent la lumière ; le récipient '
              'noir convertit l\'énergie lumineuse en chaleur interne.',
          materials: ['panneaux carton miroir', 'récipient noir', 'film transparent', 'fermoirs', 'grille'],
          tools: ['cutter', 'règle', 'colle', 'mètre'],
          budget: '≈ 10 €',
          difficulty: 3,
          time: '3-4 h',
          category: 'Cuisine',
          tags: ['solaire', 'low-tech', 'plein air'],
        ),
      ],
      stepTemplates: [
        {'title': 'Préparer les ustensiles de coupe', 'detail': 'Plane les pièces en bois, prépare le gabarit et perce les avants-trous.', 'safety': 'Maintiens la pièce avec un serre-joint pendant la coupe.', 'duration': '30 min'},
        {'title': 'Assembler le peigne ou la grille', 'detail': 'Espace régulièrement les dents/grilles et fixe-les solidement.', 'safety': '', 'duration': '45 min'},
        {'title': 'Fixer la poignée et l\'axe de pivot', 'detail': 'Monte la poignée, aligne l\'axe et vérifie le mouvement en douceur.', 'safety': '', 'duration': '30 min'},
        {'title': 'Essai avec le produit réel', 'detail': 'Teste avec des herbes/nourriture, ajuste l\'espacement si besoin.', 'safety': '', 'duration': '20 min'},
      ],
    ),
    const DomainEntry(
      name: 'atelier bricolage',
      keywords: ['atelier', 'bricol', 'établi', 'etabli', 'outillage', 'perceuse', 'rangement',
          'gabarit', 'étagère', 'etagere', 'sciure', 'tournevis', 'étau', 'etau', 'caisson'],
      inventions: [
        InvBase(
          title: 'Le Pince-Gabarit',
          problem: 'Reproduire des angles et des trous identiques à chaque pièce.',
          concept: 'Un gabarit à butée réglable qui guide perçage et tracés répétitifs '
              'sur plusieurs pièces, avec une graduation laser gravée.',
          mechanism: 'Une butée coulissante bloque la pièce au même endroit ; l\'axe de '
              'perçage est gardé par un manchon guide.',
          materials: ['chute de bois massif', 'règle métallique', 'manchon acier', 'réglages à molette', 'graduation gravée'],
          tools: ['scie sauteuse', 'perceuse à colonne', 'pince', 'mètre'],
          budget: '≈ 12 €',
          difficulty: 2,
          time: '2 h',
          category: 'Atelier',
          tags: ['gabarit', 'précision', 'récup'],
        ),
        InvBase(
          title: 'Le Bac à Vis Magique',
          problem: 'Les vis et rondelles se mélangent et se perdent au fond des tiroirs.',
          concept: 'Une table-triante inclinée avec des rainures calibrées par taille : '
              'verser les vis en vrac, agiter, et chaque vis tombe dans sa bonde-filet.',
          mechanism: 'La gravité guide les pièces le long des rainures de plus en plus '
              'larges, chaque taille basculant dans son puits de collecte.',
          materials: ['caisse à compartiments', 'grille perforée', 'butée bois', 'carton rigide', 'aimants'],
          tools: ['scie', 'perceuse', 'colle', 'pince'],
          budget: '≈ 8 €',
          difficulty: 1,
          time: '1 h 30',
          category: 'Atelier',
          tags: ['rangement', 'gain de temps', 'quincaillerie'],
        ),
      ],
      stepTemplates: [
        {'title': 'Sélectionner la chute et la surfacer', 'detail': 'Choisis un bois sain sans fissures, nettoie et surfacer à la ponceuse.', 'safety': 'Porte un masque anti-poussière lors du ponçage.', 'duration': '30 min'},
        {'title': 'Tracer les axes et percer', 'detail': 'Reporte les cotes au trusquin et perce les avant-trous avec des cales.', 'safety': 'Serre le gabarit dans l\'étau avant de percer.', 'duration': '1 h'},
        {'title': 'Assemblage à blanc puis collage', 'detail': 'Assemble sans colle pour vérifier, puis colle vissé à serrer.', 'safety': '', 'duration': '45 min'},
        {'title': 'Test de répétition', 'detail': 'Pose trois pièces identiques et vérifie la fidélité du réglage.', 'safety': '', 'duration': '20 min'},
      ],
    ),
    const DomainEntry(
      name: 'électronique',
      keywords: ['électron', 'electron', 'arduino', 'capteur', 'servo', 'moteur', 'batterie',
          'led', 'relais', 'carte', 'wifi', 'bluetooth', 'radio', 'code', 'program', 'iot', 'robot'],
      inventions: [
        InvBase(
          title: 'Le Veilleur d\'Angles Morts',
          problem: 'On ne voit jamais tous les angles d\'un local, d\'un garage ou d\'un vélo.',
          concept: 'Un capteur de présence à ultrasons avec alarme sonore monté sur '
              'double-face, alimenté par une batterie 5 V rechargeable.',
          mechanism: 'Le module HC-SR04 émet des ultrasons et mesure l\'écho ; passé un '
              'seuil, un buzzer et une LED donnent l\'alerte.',
          materials: ['module ultrasons HC-SR04', 'carte Arduino/ESP32', 'buzzer', 'LED', 'batterie 3,7 V', 'boîtier imprimé'],
          tools: ['fer à souder', 'multimètre', 'tournevis', 'pince coupante'],
          budget: '≈ 15-20 €',
          difficulty: 4,
          time: '5-6 h',
          category: 'Électronique',
          tags: ['capteur', 'sécurité', 'DIY'],
        ),
        InvBase(
          title: 'L\'Arroseur Qui Pense',
          problem: 'Les plantes sont arrosées trop ou trop peu, n\'importe quand.',
          concept: 'Un arroseur automatique : une sonde d\'humidité pilote une '
              'mini-pompe, avec indication LED de l\'état du sol.',
          mechanism: 'La sonde résistive mesure l\'humidité du sol ; sous le seuil, la '
              'pompe active par relais arrose jusqu\'à saturation.',
          materials: ['sonde d\'humidité', 'mini-pompe 5 V', 'transistor relais', 'câbles', 'bouteille réservoir', 'ESP32'],
          tools: ['fer à souder', 'multimètre', 'pince', 'thermo-retractable'],
          budget: '≈ 18 €',
          difficulty: 4,
          time: '5 h',
          category: 'Électronique',
          tags: ['automatisation', 'capteur', 'plantes'],
        ),
        InvBase(
          title: 'La Lampe Témoin de Courant',
          problem: 'On ne sait pas si un appareil consomme en veille (les « vampires » électriques).',
          concept: 'Une prise-relais avec capteur de courant qui allume une LED rouge '
              'quand l\'appareil consomme, même en veille.',
          mechanism: 'Le capteur à effet Hall mesure le courant du fil ; sous 2 W, la '
              'LED reste orange pour viser la coupure manuelle.',
          materials: ['capteur de courant ACS712', 'relais', 'LED bi-couleur', 'prise femelle', 'fils 1 mm²', 'boîtier'],
          tools: ['fer à souder', 'multimètre', 'tournevis', 'pince'],
          budget: '≈ 12 €',
          difficulty: 3,
          time: '3 h',
          category: 'Électronique',
          tags: ['économie', 'meilleures pratiques', 'mesure'],
        ),
      ],
      stepTemplates: [
        {'title': 'Schéma de câblage sur papier', 'detail': 'Dessine le schéma, vérifie les tensions et les courants avec la datasheet.', 'safety': 'Débranche toute alimentation avant de souder.', 'duration': '45 min'},
        {'title': 'Souder le montage', 'detail': 'Soude composants et connecteurs, glisse de la gaine thermo-rétractable sur les fils nus.', 'safety': 'Travaille dans un local ventilé, fer chaud sur support dédié.', 'duration': '1 h 30'},
        {'title': 'Programmer et téléverser', 'detail': 'Écris le firmware, téléverse et observe le moniteur série pour valider les seuils.', 'safety': '', 'duration': '1 h'},
        {'title': 'Boîtier et installation', 'detail': 'Installe le tout dans un boîtier, fixe les capteurs et teste en conditions réelles.', 'safety': '', 'duration': '1 h'},
      ],
    ),
    const DomainEntry(
      name: 'récupération',
      keywords: ['recycl', 'récup', 'recup', 'upcycl', 'bouteille', 'palette', 'carton',
          'boîte', 'boite', 'canette', 'chute', 'invendu', 'consomm', 'zéro déchet', 'zerodechet', 'économie circulaire', 'circulaire'],
      inventions: [
        InvBase(
          title: 'Le Palet-Oasis',
          problem: 'Les palettes jetées finissent dans les déchèteries.',
          concept: 'Transforme une palette en bac à fleurs mural avec drainage intégré, '
              'des parois renforcées et des pieds en chutes.',
          mechanism: 'La structure de la palette sert de cadre ; un géotextile crée le '
              'drainage et évite la pourriture du bois.',
          materials: ['palette', 'géotextile', 'agrafes', 'terreau', 'traitement bois', 'chutes de vis'],
          tools: ['pied-de-biche', 'marteau', 'scie sabre', 'agrafeuse', 'papier de verre'],
          budget: '≈ 5 €',
          difficulty: 2,
          time: '3 h',
          category: 'Récupération',
          tags: ['palette', 'jardin', 'zéro déchet'],
        ),
        InvBase(
          title: 'L\'Empileur de Bouteilles',
          problem: 'Les bouteilles en plastique sont trop souvent jetées.',
          concept: 'Un élément structurel autobloquant : des bouteilles remplies de sable '
              's\'empilent pour créer des étagères ou murets modulaires.',
          mechanism: 'Les cols s\'emboîtent dans les fonds évidés, la friction du poids '
              'verrouille l\'assemblage sans colle.',
          materials: ['bouteilles', 'sable', 'planches', 'élastiques', 'traitement anti-UV'],
          tools: ['cutter', 'entonnoir', 'mètre', 'tournevis'],
          budget: '≈ 4 €',
          difficulty: 1,
          time: '2 h',
          category: 'Récupération',
          tags: ['économie circulaire', 'mobilier', 'plastique'],
        ),
        InvBase(
          title: 'Le Carton Ferme',
          problem: 'Les cartons d\'emballage finissent à la benne après le déménagement.',
          concept: 'Des modules de rangement en carton ondulé plié en structure '
              'triangulaire, protégés par une finition hydrofuge naturelle.',
          mechanism: 'Le pli en accordéon et les nervures verticales donnent au carton '
              'une résistance à la compression inattendue.',
          materials: ['carton ondulé double cannelure', 'colle à bois', 'tissu/acrylique film', 'cales bois'],
          tools: ['cutter', 'règle métal', 'plan carton', 'pince'],
          budget: '≈ 3 €',
          difficulty: 2,
          time: '2 h',
          category: 'Récupération',
          tags: ['carton', 'rangement', 'fini propre'],
        ),
      ],
      stepTemplates: [
        {'title': 'Nettoyer et trier la matière', 'detail': 'Récupère des pièces propres, enlève les étiquettes et les clips métalliques.', 'safety': 'Fais attention aux clous des palettes avec un pied-de-biche.', 'duration': '30 min'},
        {'title': 'Préparer et renforcer les pièces', 'detail': 'Découpe aux dimensions, ponce et applique un traitement protecteur.', 'safety': 'Porte des gants lors de la manipulation du bois brut.', 'duration': '1 h'},
        {'title': 'Assemblage structurel', 'detail': 'Monte le cadre, fixe les renforts et pose la couche drainante/protectrice.', 'safety': '', 'duration': '1 h 15'},
        {'title': 'Finitions et prise en main', 'detail': 'Ponce les bords, nettoie, place l\'objet à son emplacement définitif.', 'safety': '', 'duration': '30 min'},
      ],
    ),
    const DomainEntry(
      name: 'énergie',
      keywords: ['solaire', 'énergie', 'energie', 'éolien', 'eolien', 'recharge', 'batterie',
          'électricité', 'electricite', 'chauffe', 'panneau', 'autonome', 'éco', 'eco', 'réchauffer', 'réfrigér'],
      inventions: [
        InvBase(
          title: 'Le Chauffe-Bidon Solaire',
          problem: 'Se laver dehors ou au jardin sans eau chaude ni électricité.',
          concept: 'Un bidon noir isolé dans un collecteur en verre incliné qui réchauffe '
              'quelques litres d\'eau en une après-midi.',
          mechanism: 'L\'absorption du noir + l\'effet de serre du verre montent la '
              'température ; l\'isolant conserve la chaleur le soir.',
          materials: ['bidon plastique noir', 'double vitrage de récupération', 'isolant polystyrène', 'cadre bois', 'miroir'],
          tools: ['scie', 'perceuse', 'agrafes', 'mètre'],
          budget: '≈ 15-20 €',
          difficulty: 3,
          time: '4 h',
          category: 'Énergie',
          tags: ['solaire', 'eau chaude', 'low-tech'],
        ),
        InvBase(
          title: 'La Pile à Marteau',
          problem: 'Produire de la lumière d\'appoint sans accumulateur fragile.',
          concept: 'Une mini dynamo à volant qui charge un condensateur pendant les '
              'gestes du quotidien (ouvrir une porte, plier un vêtement).',
          mechanism: 'Le mouvement rotatif entraîne via un pignon une dynamo de 12 V ; '
              'le condensateur stocke et restitue à la LED.',
          materials: ['moteur de récupération', 'condensateur 10 F', 'LED', 'pignons', 'boîtier'],
          tools: ['fer à souder', 'perceuse', 'pince', 'tournevis'],
          budget: '≈ 8 €',
          difficulty: 4,
          time: '4 h',
          category: 'Énergie',
          tags: ['dynamo', 'énergie libre', 'récup'],
        ),
        InvBase(
          title: 'Le Réfrigérateur du Désert',
          problem: 'Garder des aliments au frais sans réfrigérateur électrique.',
          concept: 'Une clayette-pot en terre cuite humidifiée, dont l\'évaporation '
              'refroidit l\'intérieur de quelques degrés.',
          mechanism: 'L\'eau s\'évapore à travers le pot poreux en absorbant la chaleur '
              'latente de l\'intérieur : refroidissement passif.',
          materials: ['pot en terre cuite non verni', 'sable', 'eau', 'linge', 'support'],
          tools: ['pince', 'cutter', 'seau'],
          budget: '≈ 10 €',
          difficulty: 1,
          time: '1 h',
          category: 'Énergie',
          tags: ['froid passif', 'pot en terre', 'sécurité'],
        ),
      ],
      stepTemplates: [
        {'title': 'Préparer le collecteur et l\'isolant', 'detail': 'Découpe le cadre, pose l\'isolant et prépare les surfaces réfléchissantes.', 'safety': 'Manipule le verre avec des gants.', 'duration': '1 h'},
        {'title': 'Assembler la chambre chaude ou froide', 'detail': 'Monte les parois, insère le récipient/les pots et scelle les passages d\'air.', 'safety': '', 'duration': '1 h'},
        {'title': 'Câbler ou brancher le circuit de chauffe', 'detail': 'Pour les versions électriques : soude le circuit et vérifie les isolations.', 'safety': 'Coupe toute tension avant d\'intervenir.', 'duration': '1 h'},
        {'title': 'Test thermique', 'detail': 'Mesure les températures avant/après pendant une journée et note le delta.', 'safety': '', 'duration': '1 j'},
      ],
    ),
    const DomainEntry(
      name: 'enfants',
      keywords: ['enfant', 'jouet', 'jeu', 'ludique', 'éveil', 'eveil', 'gamin', 'crèche',
          'creche', 'école', 'ecole', 'récré', 'recre', 'balançoire', 'balancoire', 'poupé'],
      inventions: [
        InvBase(
          title: 'L\'Auto-Fabrique de Maracas',
          problem: 'Des instruments fiables et surs pour jouer avec les enfants.',
          concept: 'Un lot de maracas en tubes fermés par des embouts vissés, décorées '
              'avec des matières sonores différentes (riz, pâtes, grelots).',
          mechanism: 'La chambre de résonance du tube amplifie le choc des grains — '
              'chaque garniture donne un timbre distinct.',
          materials: ['tubes PVC 4 cm', 'embouts bouchons', 'riz/pâtes/grelots', 'peinture enfant', 'colle non toxique'],
          tools: ['scie', 'cutter', 'entonnoir', 'pince'],
          budget: '≈ 6 €',
          difficulty: 1,
          time: '1 h 30',
          category: 'Enfants',
          tags: ['jouet', 'musique', 'sécurité'],
        ),
        InvBase(
          title: 'La Tour à Lancer',
          problem: 'Un jeu de motricité qui se plie pour le rangement.',
          concept: 'Une tour d\'empilage de gobelets lestés, cibles légères à lancer '
              'depuis un petit tremplin en carton plié.',
          mechanism: 'Le tremplin en carton thermoplié convertit la pression du saut '
              'en trajectoire balistique.',
          materials: ['gobelets', 'carton rigide', 'lest de sable', 'élastiques', 'décor'],
          tools: ['cutter', 'règle', 'agrafeuse'],
          budget: '≈ 4 €',
          difficulty: 1,
          time: '1 h',
          category: 'Enfants',
          tags: ['motricité', 'jeu libre', 'récup'],
        ),
      ],
      stepTemplates: [
        {'title': 'Préparer les pièces en toute sécurité', 'detail': 'Découpe, ponce et arrondis tous les bords ; utilise des matériaux non toxiques.', 'safety': 'Aucune arête vive — vérifie chaque pièce.', 'duration': '45 min'},
        {'title': 'Assembler et fermer', 'detail': 'Monte les pièces et bloque les éléments qui ne doivent pas s\'ouvrir.', 'safety': 'Vérifie que rien n\'est avalable ou vulnérable.', 'duration': '45 min'},
        {'title': 'Décorer ensemble', 'detail': 'Laisse les enfants peindre/décorer : ça renforce le lien à l\'objet.', 'safety': 'Peintures à l\'eau non toxiques.', 'duration': '45 min'},
        {'title': 'Test grandeur nature', 'detail': 'Essaie le jeu avec les enfants et observe leur façon de l\'utiliser.', 'safety': '', 'duration': '30 min'},
      ],
    ),
    const DomainEntry(
      name: 'mobilité',
      keywords: ['vélo', 'velo', 'moto', 'sac', 'gadget', 'bagagerie', 'transport', 'camping',
          'randonnée', 'randonnee', 'trek', 'voyage', 'trajet', 'transport', 'voiture', 'séjour'],
      inventions: [
        InvBase(
          title: 'Le Protège-Sac Anti-Éclaboussure',
          problem: 'Le sac à dos prend l\'eau sur le vélo ou en scooter.',
          concept: 'Une housse pliable à coutures étanches, avec un soufflet arrière qui '
              'monte un parapluie de courtoisie pour le dos.',
          mechanism: 'Le soufflet creux crée un coussin d\'air isolant du frottement ; '
              'l\'élasticité la maintient tendue sans gêner le mouvement.',
          materials: ['tissu déperlant', 'élastique', 'ceinture', 'glissières', 'ruban PVC'],
          tools: ['machine à coudre', 'ciseaux', 'règle'],
          budget: '≈ 8 €',
          difficulty: 2,
          time: '2 h',
          category: 'Mobilité',
          tags: ['vélo', 'pluie', 'couture'],
        ),
        InvBase(
          title: 'Le Rack d\'Appoint',
          problem: 'Transporter un carton ou une valise sur un vélo qui n\'a pas de porteur.',
          concept: 'Un porte-bagages à gorge qui se fixe sur la tige de selle et l\'axe '
              'de roue, pliable quand il ne sert pas.',
          mechanism: 'La pince à gorge épouse la selle et l\'axe ; le plateau triangulaire '
              'répartit la charge sur le cadre.',
          materials: ['profilé aluminium', 'pince à gorge', 'vis', 'caoutchouc', 'cales'],
          tools: ['scie à métaux', 'perceuse', 'clés Allen', 'mètre'],
          budget: '≈ 15 €',
          difficulty: 3,
          time: '3 h',
          category: 'Mobilité',
          tags: ['vélo', 'chargement', 'bricolage'],
        ),
      ],
      stepTemplates: [
        {'title': 'Relevé des cotes du vélo/housse existant', 'detail': 'Mesure tige de selle, axe de roue ou dimensions du sac.', 'safety': '', 'duration': '20 min'},
        {'title': 'Découpe du profilé / du tissu', 'detail': 'Découpe au gabarit et prépare les trous de fixation.', 'safety': 'Porte des lunettes pour la découpe du métal.', 'duration': '1 h'},
        {'title': 'Assemblage et réglage', 'detail': 'Monte le support, règle la tension et fixe le revêtement antidérapant.', 'safety': 'Vérifie le serrage avant roulage.', 'duration': '1 h'},
        {'title': 'Essai en charge puis en condition réelle', 'detail': 'Roule avec une charge, vérifie la stabilité des virages.', 'safety': '', 'duration': '45 min'},
      ],
    ),
    const DomainEntry(
      name: 'bureau',
      keywords: ['bureau', 'câble', 'cable', 'organise', 'classement', 'papier', 'document',
          'secrétaire', 'secretaire', 'rangement bureau', 'écran', 'ecran', 'étagère bureau',
          'stylo', 'post-it', 'postit'],
      inventions: [
        InvBase(
          title: 'Le Câble-O Chien',
          problem: 'Les câbles du bureau se mélangent sous la table.',
          concept: 'Un goulot passe-câbles en rail aimanté qui canalise les nappes, avec '
              'des étiquettes-languettes à chaque extrémité.',
          mechanism: 'Le rail à clip se fixe sous le plateau ; la languette amovible '
              'identifie chaque câble sans les débrancher.',
          materials: ['rail en U', 'aimants', 'clip imprimé', 'ruban adhésif double face', 'étiquettes'],
          tools: ['perceuse', 'tournevis', 'couteau'],
          budget: '≈ 5 €',
          difficulty: 1,
          time: '45 min',
          category: 'Bureau',
          tags: ['organisation', 'câbles', 'quick win'],
        ),
        InvBase(
          title: 'Le Tri-Esprit',
          problem: 'Le papier s\'empile avant de finir trié ou archivé.',
          concept: 'Une mallette-trieuse à 4 cases pivotantes (À traiter / À lire / À '
              'signer / À archiver) avec des indicateurs de priorité.',
          mechanism: 'Les casiers tournent sur un axe central ; la fente frontale permet '
              'd\'insérer sans reclasser.',
          materials: ['carton épais', 'axis bois', 'vis', 'étiquettes', 'film hydrofuge'],
          tools: ['cutter', 'règle', 'perceuse', 'pince'],
          budget: '≈ 7 €',
          difficulty: 2,
          time: '2 h',
          category: 'Bureau',
          tags: ['organisation', 'papier', 'rythme'],
        ),
      ],
      stepTemplates: [
        {'title': 'Mesurer l\'espace et les volumes', 'detail': 'Repère l\'espace sous la table ou côté bureau et mesure ce qui y cohabite.', 'safety': '', 'duration': '20 min'},
        {'title': 'Préparer les rails/casiers', 'detail': 'Découpe les pièces, perfore les fixations et prépare les attaches.', 'safety': '', 'duration': '45 min'},
        {'title': 'Fixer et orienter', 'detail': 'Pose le support, règle les angles et teste le passage des câbles/liasses.', 'safety': '', 'duration': '45 min'},
        {'title': 'Étiqueter et mettre en service', 'detail': 'Implémente un code couleur simple pour le tri quotidien.', 'safety': '', 'duration': '20 min'},
      ],
    ),
    const DomainEntry(
      name: 'animaux',
      keywords: ['chat', 'chien', 'animal', 'litière', 'litiere', 'gamelle', 'cage', 'voliè',
          'voilier', 'mangeoire', 'nourri', 'griffoir', 'aquarium', 'nichoir', 'oiseau'],
      inventions: [
        InvBase(
          title: 'Le Mange-Sec Automatique',
          problem: 'Le chat mange toute sa gamelle d\'un coup puis mendie.',
          concept: 'Un distributeur à gravité couplé à un volet temporisé qui libère des '
              'rations programmées quotidiennes.',
          mechanism: 'Un flotteur détend un ressort qui bascule un volet : la ration '
              'libérée est bornée par la course du levier.',
          materials: ['bidon alimentaire', 'volet plastique', 'ressort', 'axe métallique', 'pieds antidérapants'],
          tools: ['perceuse', 'scie', 'pince', 'tournevis'],
          budget: '≈ 10 €',
          difficulty: 2,
          time: '2 h',
          category: 'Animaux',
          tags: ['autonomie', 'chat', 'nutrition'],
        ),
        InvBase(
          title: 'Le Grattoir à Fossile',
          problem: 'Le chat griffe les canapés pour marquer son territoire.',
          concept: 'Un griffoir vertical en sisal fixé en coin, avec un plateau incliné '
              'qui dirige naturellement le geste de griffage.',
          mechanism: 'La forme de coin respecte l\'instinct de griffage vertical ; le '
              'sisal rugueux est plus apprécié que le tissu du canape.',
          materials: ['corde sisal', 'planche', 'coin de renfort', 'agrafes', 'herbe à chat'],
          tools: ['agrafeuse', 'scie', 'perceuse', 'pince'],
          budget: '≈ 8 €',
          difficulty: 1,
          time: '1 h 30',
          category: 'Animaux',
          tags: ['chat', 'griffoir', 'sisal'],
        ),
      ],
      stepTemplates: [
        {'title': 'Préparer un matériau sûr et lavable', 'detail': 'Choisis des matériaux non toxiques et résistants aux griffes/dents.', 'safety': 'Évite tout produit traité ou vernis toxique.', 'duration': '20 min'},
        {'title': 'Assembler la structure', 'detail': 'Monte et solidarise les pièces, fixe le sisal en spirale.', 'safety': '', 'duration': '1 h'},
        {'title': 'Tests avec l\'animal', 'detail': 'Observe la réaction, ajuste la hauteur et la position.', 'safety': '', 'duration': '1 j'},
      ],
    ),
    const DomainEntry(
      name: 'bien-être',
      keywords: ['posture', 'douleur', 'ergonomie', 'massage', 'relaxation', 'dos', 'cou',
          'réveil', 'reveil', 'sommeil', 'routine', 'attention', 'concentration', 'door', 'gestion'],
      inventions: [
        InvBase(
          title: 'Le Coussin-Horreur',
          problem: 'Mal de dos après les longues sessions assis.',
          concept: 'Un coussin de posture gonflable à deux zones qui bascule doucement '
              'le bassin vers l\'avant, en soutien lombaire réglable.',
          mechanism: 'La pression d\'air différenciée incline le bassin et rapproche la '
              'lombaires de sa courbure naturelle.',
          materials: ['sac étanche robuste', 'valve d\'insufflation', 'tissu de coussin', 'réglage à valve', 'mousse'],
          tools: ['machine à coudre', 'valve', 'ciseaux'],
          budget: '≈ 12 €',
          difficulty: 2,
          time: '2 h',
          category: 'Bien-être',
          tags: ['posture', 'ergonomie', 'fait main'],
        ),
        InvBase(
          title: 'Le Semainier de l\'Esprit',
          problem: 'Surcharge mentale : des idées entreposées, des tâches floues.',
          concept: 'Un tableau de pilotage en 4 cadrans (À faire / En cours / À déléguer / '
              'À rêver) avec cartes « étincelles » pour y déposer les idées.',
          mechanism: 'La vue d\'ensemble réduit la charge mentale ; le cadran « à rêver » '
              'protège les idées fertiles sans obligation.',
          materials: ['panneau', 'porte-cartes', 'cartes carton', 'feutres', 'aimants'],
          tools: ['perceuse', 'scie', 'agrafeuse'],
          budget: '≈ 9 €',
          difficulty: 1,
          time: '1 h 30',
          category: 'Bien-être',
          tags: ['organisation', 'charge mentale', 'routines'],
        ),
      ],
      stepTemplates: [
        {'title': 'Définir l\'usage et les mesures', 'detail': 'Définis la position d\'usage et relève les dimensions utiles.', 'safety': '', 'duration': '20 min'},
        {'title': 'Préparer et découper', 'detail': 'Coupe et prépare les pièces du support.', 'safety': '', 'duration': '45 min'},
        {'title': 'Assembler et régler', 'detail': 'Monte, règle les tensions/valves et teste l\'ergonomie.', 'safety': 'Vérifie les pressions au-delà des limites de confort.', 'duration': '45 min'},
        {'title': 'Test d\'usage sur une semaine', 'detail': 'Utilise le dispositif une semaine et note l\'effet ressenti.', 'safety': '', 'duration': '1 sem'},
      ],
    ),
  ];
}

class _Match {
  final DomainEntry? domain;
  final InvBase? base;
  const _Match({this.domain, this.base});
}

class _Ctx {
  final String title;
  final String problem;
  final String id;
  final String category;
  final String concept;
  final String mechanism;
  final List<String> materials;
  final List<String> tools;
  final String budget;
  final String time;
  final int? difficulty;
  final List<String> tags;
  const _Ctx({
    this.title = '',
    this.problem = '',
    this.id = '',
    this.category = '',
    this.concept = '',
    this.mechanism = '',
    this.materials = const [],
    this.tools = const [],
    this.budget = '',
    this.time = '',
    this.difficulty,
    this.tags = const [],
  });
  static const empty = _Ctx();
}