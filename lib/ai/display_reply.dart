import '../models/chat_turn.dart';
import '../models/concept.dart';
import '../models/idea_evaluation.dart';
import '../models/invention_project.dart';
import '../models/json_utils.dart';
import 'ai_response.dart';
import 'lenient_json.dart';

/// Ce qu'une bulle assistant doit afficher, reconstruit à partir d'un tour de
/// conversation enregistré.
///
/// Les réponses enregistrées par les versions ≤ 1.0.3 peuvent contenir du JSON
/// brut dans `content` (réponse tronquée) : on les ré-interprète à l'affichage,
/// sans modifier les données enregistrées.
class DisplayReply {
  final String message;
  final String intent;
  final InventionProject? project;
  final ProjectPlan? plan;
  final IdeaEvaluation? evaluation;
  final Map<String, dynamic>? evaluationJson;
  final SparkContent? spark;
  final List<InventionConcept> concepts;
  final List<String> resources;
  final String? journalText;
  final String? projectId;
  final String? sparkId;
  final String? provider;
  final String? raw;
  final bool partial;
  final bool success;

  const DisplayReply({
    required this.message,
    this.intent = 'none',
    this.project,
    this.plan,
    this.evaluation,
    this.evaluationJson,
    this.spark,
    this.concepts = const [],
    this.resources = const [],
    this.journalText,
    this.projectId,
    this.sparkId,
    this.provider,
    this.raw,
    this.partial = false,
    this.success = true,
  });

  factory DisplayReply.fromTurn(ChatTurn turn) {
    final payload = turn.payload ?? const <String, dynamic>{};
    final projectId = jsonStringOrNull(payload['projectId']);
    final sparkId = jsonStringOrNull(payload['sparkId']);
    final provider = jsonStringOrNull(payload['provider']);

    final storedHasData = payload['project'] != null ||
        payload['plan'] != null ||
        payload['evaluation'] != null ||
        payload['spark'] != null ||
        payload['concepts'] != null;

    // Ancienne réponse brute : on la ré-interprète.
    if (!storedHasData && LenientJson.looksLikeJson(turn.content)) {
      final r = NabuAiResponse.parse(turn.content, provider ?? '');
      final evalJson = r.evaluation?.toJson();
      return DisplayReply(
        message: r.message,
        intent: r.intent.name,
        project: r.project,
        plan: r.plan,
        evaluation: r.evaluation,
        evaluationJson: evalJson,
        spark: r.spark,
        concepts: r.concepts,
        resources: r.resources,
        journalText: r.journalText,
        projectId: projectId,
        sparkId: sparkId,
        provider: provider,
        raw: r.raw ?? turn.content,
        partial: r.partial,
        success: r.success,
      );
    }

    final projectJson = jsonMap(payload['project']);
    final planJson = jsonMap(payload['plan']);
    final evalJson = jsonMap(payload['evaluation']);
    final sparkJson = jsonMap(payload['spark']);
    return DisplayReply(
      message: turn.content,
      intent: jsonString(payload['intent'], 'none'),
      project: projectJson == null ? null : InventionProject.fromJson(projectJson),
      plan: planJson == null ? null : ProjectPlan.fromJson(planJson),
      evaluation: evalJson == null ? null : IdeaEvaluation.fromJson(evalJson),
      evaluationJson: evalJson,
      spark: sparkJson == null ? null : SparkContent.fromJson(sparkJson),
      concepts: conceptsFromJson(payload['concepts']),
      resources: jsonStringList(payload['resources']),
      journalText: jsonStringOrNull(payload['journalText']),
      projectId: projectId,
      sparkId: sparkId,
      provider: provider,
      raw: jsonStringOrNull(payload['raw']),
      partial: jsonBool(payload['partial']),
      success: jsonBool(payload['success'], true),
    );
  }
}
