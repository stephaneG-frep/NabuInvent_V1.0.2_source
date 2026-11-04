import '../models/concept.dart';
import '../models/idea_evaluation.dart';
import '../models/invention_project.dart';
import '../models/json_utils.dart';
import '../models/tech_sheet.dart';
import 'lenient_json.dart';
import 'redact.dart';

enum AiIntent { invent, plan, evaluate, spark, journal, refine, explain, concepts, techsheet, none }

AiIntent intentFromName(String? name) {
  switch (name?.toLowerCase()) {
    case 'invent':
      return AiIntent.invent;
    case 'plan':
      return AiIntent.plan;
    case 'evaluate':
      return AiIntent.evaluate;
    case 'spark':
      return AiIntent.spark;
    case 'journal':
      return AiIntent.journal;
    case 'refine':
      return AiIntent.refine;
    case 'explain':
      return AiIntent.explain;
    case 'concepts':
      return AiIntent.concepts;
    case 'techsheet':
      return AiIntent.techsheet;
    default:
      return AiIntent.none;
  }
}

class SparkContent {
  final String title;
  final String domain;
  final String mechanism;
  final String material;
  final String pitch;
  final bool challenge;

  SparkContent({
    this.title = '',
    this.domain = '',
    this.mechanism = '',
    this.material = '',
    this.pitch = '',
    this.challenge = false,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'domain': domain,
        'mechanism': mechanism,
        'material': material,
        'pitch': pitch,
        'challenge': challenge,
      };

  factory SparkContent.fromJson(Map<String, dynamic> json) => SparkContent(
        title: jsonString(json['title']),
        domain: jsonString(json['domain']),
        mechanism: jsonString(json['mechanism']),
        material: jsonString(json['material']),
        pitch: jsonString(json['pitch']),
        challenge: jsonBool(json['challenge']),
      );
}

class NabuAiResponse {
  final String provider;
  final String message;
  final AiIntent intent;
  final InventionProject? project;
  final ProjectPlan? plan;
  final IdeaEvaluation? evaluation;
  final SparkContent? spark;

  /// Variantes proposées par l'atelier (intent = concepts).
  final List<InventionConcept> concepts;

  /// Ressources identifiées dans la demande (mode inventeur autonome).
  final List<String> resources;

  /// Fiche technique proposée (intent = techsheet).
  final TechSheet? techSheet;
  final String? journalText;
  final bool success;
  final String? error;

  /// Texte reçu du modèle, secrets masqués, pour le mode technique.
  /// Null quand la réponse était du texte simple (identique à [message]).
  final String? raw;

  /// true si la réponse était un JSON incomplet ou abîmé, réparé au mieux.
  final bool partial;

  NabuAiResponse({
    required this.provider,
    required this.message,
    this.intent = AiIntent.none,
    this.project,
    this.plan,
    this.evaluation,
    this.spark,
    this.concepts = const [],
    this.resources = const [],
    this.techSheet,
    this.journalText,
    this.success = true,
    this.error,
    this.raw,
    this.partial = false,
  });

  /// Limite du texte brut conservé : il est enregistré avec la conversation.
  static const maxRawLength = 60000;

  bool get hasProject => project != null;

  bool get hasStructuredContent =>
      project != null ||
      plan != null ||
      evaluation != null ||
      spark != null ||
      concepts.isNotEmpty ||
      techSheet != null;

  NabuAiResponse _withMeta({String? message, String? raw, bool? partial}) =>
      NabuAiResponse(
        provider: provider,
        message: message ?? this.message,
        intent: intent,
        project: project,
        plan: plan,
        evaluation: evaluation,
        spark: spark,
        concepts: concepts,
        resources: resources,
        techSheet: techSheet,
        journalText: journalText,
        success: success,
        error: error,
        raw: raw ?? this.raw,
        partial: partial ?? this.partial,
      );

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'message': message,
        'intent': intent.name,
        if (project != null) 'project': project!.toJson(),
        if (plan != null) 'plan': plan!.toJson(),
        if (evaluation != null) 'evaluation': evaluation!.toJson(),
        if (spark != null) 'spark': spark!.toJson(),
        if (concepts.isNotEmpty) 'concepts': [for (final c in concepts) c.toJson()],
        if (resources.isNotEmpty) 'resources': resources,
        if (techSheet != null) 'techSheet': techSheet!.toJson(),
        if (journalText != null) 'journalText': journalText,
        'success': success,
        if (error != null) 'error': error,
        if (raw != null) 'raw': raw,
        if (partial) 'partial': true,
      };

  factory NabuAiResponse.fromJson(Map<String, dynamic> json,
      {String defaultProvider = 'IA'}) {
    final projectJson = jsonMap(json['project']);
    final project =
        projectJson == null ? null : InventionProject.fromJson(projectJson);
    final planJson = jsonMap(json['plan']);
    var plan = planJson == null ? null : ProjectPlan.fromJson(planJson);
    // Un modèle peut ne renvoyer le plan que dans "project.plan".
    if ((plan == null || plan.steps.isEmpty) &&
        project != null &&
        project.plan.steps.isNotEmpty) {
      plan = project.plan;
    }
    final evalJson = jsonMap(json['evaluation']);
    final sparkJson = jsonMap(json['spark']);
    return NabuAiResponse(
      provider: jsonString(json['provider'], defaultProvider),
      message: jsonString(json['message']),
      intent: intentFromName(jsonStringOrNull(json['intent'])),
      project: project,
      plan: plan,
      evaluation: evalJson == null ? null : IdeaEvaluation.fromJson(evalJson),
      spark: sparkJson == null ? null : SparkContent.fromJson(sparkJson),
      concepts: conceptsFromJson(json['concepts']),
      resources: jsonStringList(json['resources']),
      techSheet: jsonMap(json['techSheet']) == null
          ? null
          : TechSheet.fromJson(jsonMap(json['techSheet'])!),
      journalText: jsonStringOrNull(json['journalText']),
      success: jsonBool(json['success'], true),
      error: jsonStringOrNull(json['error']),
      raw: jsonStringOrNull(json['raw']),
      partial: jsonBool(json['partial']),
    );
  }

  /// Interprète la réponse d'un modèle. Le JSON n'est jamais renvoyé tel quel
  /// comme message : il est réparé si possible, sinon on en extrait le texte
  /// lisible, et l'original reste disponible dans [raw] (mode technique).
  static NabuAiResponse parse(String content, String provider) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return NabuAiResponse(provider: provider, message: '(réponse vide)', success: false);
    }
    final raw = redactSecrets(trimmed.length > maxRawLength
        ? trimmed.substring(0, maxRawLength)
        : trimmed);

    final decoded = LenientJson.decodeObject(trimmed);
    final json = decoded.map;
    if (json != null) {
      try {
        final res = NabuAiResponse.fromJson(json, defaultProvider: provider);
        if (res.message.trim().isNotEmpty ||
            res.intent != AiIntent.none ||
            res.hasStructuredContent) {
          return res._withMeta(
            message: res.message.trim().isNotEmpty
                ? null
                : (decoded.repaired ? _truncatedNotice : 'Voici le résultat.'),
            raw: raw,
            partial: decoded.repaired,
          );
        }
      } catch (_) {
        // JSON lisible mais structure inattendue : on garde au moins le message.
        final msg = jsonString(json['message']);
        if (msg.trim().isNotEmpty) {
          return NabuAiResponse(provider: provider, message: msg, raw: raw, partial: true);
        }
      }
    }

    if (LenientJson.looksLikeJson(trimmed)) {
      final msg = LenientJson.extractMessage(trimmed);
      return NabuAiResponse(
        provider: provider,
        message: msg ??
            'La réponse du modèle est illisible (JSON invalide). Réessaie, ou active '
                'le mode technique dans les Réglages pour voir le texte reçu.',
        raw: raw,
        partial: true,
        success: msg != null,
      );
    }

    // Réponse en texte simple (éventuellement mis en forme) : affichée telle quelle.
    return NabuAiResponse(provider: provider, message: trimmed);
  }

  static const _truncatedNotice =
      'La réponse du modèle a été coupée avant la fin : voici ce qui a pu être récupéré.';
}

/// Liste de concepts depuis le JSON du modèle (entrées invalides ignorées).
List<InventionConcept> conceptsFromJson(Object? v) => [
      if (v is List)
        for (final e in v)
          if (jsonMap(e) case final m?)
            if (jsonString(m['name'], jsonString(m['title'])).trim().isNotEmpty)
              InventionConcept.fromJson(m),
    ];

class AiError {
  final String message;
  const AiError(this.message);
}

class AiTurn {
  final String role;
  final String content;
  const AiTurn(this.role, this.content);

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class AiContract {
  static const systemPrompt = '''
Tu es NabuInvent AI, un agent inventeur, bricoleur et créatif. Tu aides l'utilisateur à
inventer des objets, à élaborer des plans de construction pas à pas, à évaluer des idées
et à booster sa créativité.

Répond UNIQUEMENT avec un objet JSON valide, sans texte avant ou après. Schéma :
{
  "message": "Réponse courte en français destinée à l'utilisateur (2-5 phrases).",
  "intent": "invent | concepts | techsheet | plan | evaluate | spark | journal | refine | explain | none",
  "project": { // optionnel, rempli pour invent/refine/plan
    "id": string, // uniquement pour plan/refine du projet en cours : reprends son "id"
    "title": string, "problem": string, "subtitle": string, "concept": string,
    "mechanism": string, "materials": [string], "tools": [string],
    "budget": string, "timeEstimate": string, "difficulty": 1-5,
    "category": string, "score": int, "tags": [string], "status": "idea|plan|building|built|shelved",
    "plan": { // optionnel
      "notes": string, "duration": string, "budget": string, "difficulty": string,
      "steps": [{"title": string, "detail": string, "duration": string, "safety": string, "materials": [string], "tools": [string], "objective": string, "dimensions": string, "tips": string}]
    }
  },
  "plan": { // optionnel, intent=plan : même structure que "project.plan"
    "notes": string, "duration": string, "budget": string, "difficulty": string,
    "steps": [{"title": string, "detail": string, "duration": string, "safety": string, "materials": [string], "tools": [string], "objective": string, "dimensions": string, "tips": string}]
  },
  "evaluation": { // optionnel, intent=evaluate
    "idea": string, "originality": 0-100, "feasibility": 0-100, "cost": 0-100,
    "effort": 0-100, "impact": 0-100, "verdict": string, "pitch": string,
    "strengths": [string], "risks": [string], "nextSteps": [string]
  },
  "spark": { // optionnel, intent=spark
    "title": string, "domain": string, "mechanism": string, "material": string,
    "pitch": string, "challenge": bool
  },
  "concepts": [ // optionnel, intent=concepts : jusqu'à 3 variantes PAR objet demandé
    {"subject": string, // objet concerné, ex. "Canard" ou "Héron"
     "name": string, "description": string, "style": string,
     "materials": [string], "dimensions": string, // ordre de grandeur, ex. "≈ 40 × 25 cm (indicatif)"
     "difficulty": 1-5, "time": string, "budget": string,
     "advantages": [string], "constraints": [string],
     "why": string, // raison du choix (surtout en mode ressources)
     "feasibility": 0-100} // faisabilité avec les ressources citées
  ],
  "resources": [string], // optionnel : ressources identifiées dans la demande
  "techSheet": { // optionnel, intent=techsheet : fiche technique du projet en cours
    "objective": string, "method": string,
    "dimensions": [{"label": "Hauteur totale", "value": mm ou null, "source": "user|ai"}],
    "parts": [{"name": string, "material": string, "shape": "box|bar|sheet|cylinder",
               "orientation": "flat|upright|depth", // longueur couchée selon la largeur, vers le haut, ou vers l'arrière
               "quantity": int, "length": mm ou null, "width": mm ou null, "thickness": mm ou null,
               "x": mm, "y": mm, "z": mm, // position dans l'assemblage (coin bas-gauche-avant)
               "source": "user|ai", "fastening": string, "unitPrice": euros ou null}],
    "fasteners": [string], "finishes": [string], "precautions": [string],
    "unknowns": [string] // ce qu'il faut encore mesurer ou décider
  },
  "journalText": "texte optionnel de journal de création à sauvegarder"
}

Consignes :
- Si l'utilisateur décrit ce qu'il veut fabriquer sans avoir choisi de version, demande des idées ou plusieurs objets
  (ex. « un canard et un héron avec des boîtes de conserve ») -> intent=concepts : identifie CHAQUE objet,
  propose jusqu'à 3 variantes réellement différentes par objet (style, technique d'assemblage, niveau),
  réalisables avec les matériaux et la destination indiqués. Pas de réponse générale.
- Si l'utilisateur liste ce qu'il possède (« j'ai des boîtes, du fil de fer… trouve-moi quelque chose ») -> intent=concepts :
  remplis "resources", imagine plusieurs usages, classe-les par faisabilité, explique "why" pour chacun.
  Pose une question dans "message" seulement si une information indispensable manque.
- Si l'utilisateur demande une fiche technique, des cotes, une nomenclature ou des dimensions -> intent=techsheet
  avec "techSheet" et "project" (même "id") : pièces cotées en millimètres. Une cote donnée par l'utilisateur
  a "source": "user" ; toute autre cote est une hypothèse "source": "ai". Si une cote ne peut pas être
  raisonnablement proposée, mets null et ajoute-la dans "unknowns". Les calculs (quantités, chutes, budget)
  sont refaits par l'application : contente-toi de cotes cohérentes.
- Si l'utilisateur demande une invention précise -> intent=invent avec un "project" complet et original (sans "id" : c'est un nouveau projet).
- Si l'utilisateur demande un plan/étapes -> intent=plan, renvoie "plan" avec 5 à 9 étapes concrètes ; s'il y a un projet en cours, renvoie aussi "project" avec son "id".
- Si l'utilisateur veut améliorer le projet en cours -> intent=refine avec "project" (même "id").
- Les nombres (difficulty, score, scores d'évaluation) sont des entiers JSON, pas des chaînes.
- Si l'utilisateur demande une évaluation -> intent=evaluate avec un "evaluation" (scores sur 100).
- Si l'utilisateur demande une étincelle/défi -> intent=spark avec un "spark".
- Si l'utilisateur demande une note de journal -> intent=journal avec "journalText".
- Sinon intent=none avec une simple "message" utile.
- "cost" dans evaluation: 0 = très bon marché, 100 = très coûteux.
- "difficulty" project: 1 = très simple, 5 = très complexe.
- Honnêteté : les dimensions, durées et budgets sont des estimations ; écris-les comme telles
  (« ≈ », « environ », « indicatif »). N'invente jamais une mesure comme si elle avait été relevée.
- Sécurité : signale les risques réels (bords coupants du métal, stabilité, électricité, produits chimiques)
  dans "safety" ou "constraints" ; n'affirme jamais qu'un assemblage est sûr sans éléments suffisants.
- Réponds toujours en français.
''';

  // L'historique est transmis à part, sous forme de messages : il ne doit pas
  // être recopié ici (sinon il est envoyé deux fois et coûte double).
  static String buildUserContent({
    required String userText,
    String? projectContext,
  }) {
    final buf = StringBuffer();
    if (projectContext != null && projectContext.isNotEmpty) {
      buf.write('Projet en cours (contexte) :\n$projectContext\n');
    }
    buf.write('Demande de l\'utilisateur :\n$userText');
    return buf.toString();
  }
}