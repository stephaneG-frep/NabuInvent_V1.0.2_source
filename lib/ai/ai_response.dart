import 'dart:convert';

import '../models/idea_evaluation.dart';
import '../models/invention_project.dart';
import '../models/json_utils.dart';

enum AiIntent { invent, plan, evaluate, spark, journal, refine, explain, none }

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
  final String? journalText;
  final bool success;
  final String? error;

  NabuAiResponse({
    required this.provider,
    required this.message,
    this.intent = AiIntent.none,
    this.project,
    this.plan,
    this.evaluation,
    this.spark,
    this.journalText,
    this.success = true,
    this.error,
  });

  bool get hasProject => project != null;

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'message': message,
        'intent': intent.name,
        if (project != null) 'project': project!.toJson(),
        if (plan != null) 'plan': plan!.toJson(),
        if (evaluation != null) 'evaluation': evaluation!.toJson(),
        if (spark != null) 'spark': spark!.toJson(),
        if (journalText != null) 'journalText': journalText,
        'success': success,
        if (error != null) 'error': error,
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
      journalText: jsonStringOrNull(json['journalText']),
      success: jsonBool(json['success'], true),
      error: jsonStringOrNull(json['error']),
    );
  }

  static NabuAiResponse parse(String content, String provider) {
    final trimmed = content.trim();
    var jsonStr = trimmed;
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      jsonStr = trimmed.substring(start, end + 1);
    }
    Map<String, dynamic>? json;
    try {
      json = jsonMap(jsonDecode(jsonStr));
    } catch (_) {
      json = null;
    }
    if (json != null) {
      try {
        final res = NabuAiResponse.fromJson(json, defaultProvider: provider);
        if (res.message.trim().isNotEmpty || res.intent != AiIntent.none) {
          return res;
        }
      } catch (_) {
        // JSON valide mais structure inattendue : on garde au moins le message.
        final msg = jsonString(json['message']);
        if (msg.trim().isNotEmpty) {
          return NabuAiResponse(provider: provider, message: msg);
        }
      }
    }
    return NabuAiResponse(
      provider: provider,
      message: trimmed.isEmpty ? '(réponse vide)' : trimmed,
      success: trimmed.isNotEmpty,
    );
  }
}

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
  "intent": "invent | plan | evaluate | spark | journal | refine | explain | none",
  "project": { // optionnel, rempli pour invent/refine/plan
    "id": string, // uniquement pour plan/refine du projet en cours : reprends son "id"
    "title": string, "problem": string, "subtitle": string, "concept": string,
    "mechanism": string, "materials": [string], "tools": [string],
    "budget": string, "timeEstimate": string, "difficulty": 1-5,
    "category": string, "score": int, "tags": [string], "status": "idea|plan|building|built|shelved",
    "plan": { // optionnel
      "notes": string, "duration": string, "budget": string, "difficulty": string,
      "steps": [{"title": string, "detail": string, "duration": string, "safety": string, "materials": [string], "tools": [string]}]
    }
  },
  "plan": { // optionnel, intent=plan : même structure que "project.plan"
    "notes": string, "duration": string, "budget": string, "difficulty": string,
    "steps": [{"title": string, "detail": string, "duration": string, "safety": string, "materials": [string], "tools": [string]}]
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
  "journalText": "texte optionnel de journal de création à sauvegarder"
}

Consignes :
- Si l'utilisateur demande une invention -> intent=invent avec un "project" complet et original (sans "id" : c'est un nouveau projet).
- Si l'utilisateur demande un plan/étapes -> intent=plan, renvoie "plan" avec 5 à 9 étapes concrètes ; s'il y a un projet en cours, renvoie aussi "project" avec son "id".
- Si l'utilisateur veut améliorer le projet en cours -> intent=refine avec "project" (même "id").
- Les nombres (difficulty, score, scores d'évaluation) sont des entiers JSON, pas des chaînes.
- Si l'utilisateur demande une évaluation -> intent=evaluate avec un "evaluation" (scores sur 100).
- Si l'utilisateur demande une étincelle/défi -> intent=spark avec un "spark".
- Si l'utilisateur demande une note de journal -> intent=journal avec "journalText".
- Sinon intent=none avec une simple "message" utile.
- "cost" dans evaluation: 0 = très bon marché, 100 = très coûteux.
- "difficulty" project: 1 = très simple, 5 = très complexe.
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