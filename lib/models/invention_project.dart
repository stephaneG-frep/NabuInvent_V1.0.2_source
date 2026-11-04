import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'json_utils.dart';
import 'tech_sheet.dart';

const _uuid = Uuid();

enum ProjectStatus {
  idea('idée', Icons.lightbulb_outline, Color(0xFFF2B950)),
  plan('plan prêt', Icons.architecture, Color(0xFF64B5F6)),
  building('en construction', Icons.construction, Color(0xFFBA68C8)),
  built('construit', Icons.check_circle_outline, Color(0xFF81C784)),
  shelved('en attente', Icons.hourglass_empty, Color(0xFF90A4AE));

  const ProjectStatus(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  static ProjectStatus fromName(String? name) {
    for (final s in ProjectStatus.values) {
      if (s.name == name) return s;
    }
    return ProjectStatus.idea;
  }

  static ProjectStatus fromLabel(String label) {
    for (final s in ProjectStatus.values) {
      if (s.label == label) return s;
    }
    return ProjectStatus.idea;
  }

  static List<String> get labels => ProjectStatus.values.map((v) => v.label).toList();
}

class PlanStep {
  final String id;
  final String title;
  final String detail;
  final String duration;
  final String safety;
  final List<String> materials;
  final List<String> tools;

  /// But de l'étape (mode « On le fabrique ! »).
  final String objective;

  /// Cotes utiles à cette étape.
  final String dimensions;

  /// Astuces de réalisation.
  final String tips;
  bool done;

  PlanStep({
    required this.id,
    required this.title,
    required this.detail,
    this.duration = '',
    this.safety = '',
    List<String>? materials,
    List<String>? tools,
    this.objective = '',
    this.dimensions = '',
    this.tips = '',
    this.done = false,
  })  : materials = materials ?? [],
        tools = tools ?? [];

  bool get isDone => done;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'detail': detail,
        'duration': duration,
        'safety': safety,
        'materials': materials,
        'tools': tools,
        if (objective.isNotEmpty) 'objective': objective,
        if (dimensions.isNotEmpty) 'dimensions': dimensions,
        if (tips.isNotEmpty) 'tips': tips,
        'done': done,
      };

  factory PlanStep.fromJson(Map<String, dynamic> json) {
    final id = jsonString(json['id']);
    return PlanStep(
      id: id.isNotEmpty ? id : _uuid.v4(),
      title: jsonString(json['title']),
      detail: jsonString(json['detail']),
      duration: jsonString(json['duration']),
      safety: jsonString(json['safety']),
      materials: jsonStringList(json['materials']),
      tools: jsonStringList(json['tools']),
      objective: jsonString(json['objective']),
      dimensions: jsonString(json['dimensions']),
      tips: jsonString(json['tips']),
      done: jsonBool(json['done']),
    );
  }
}

class ProjectPlan {
  final String notes;
  final String duration;
  final String budget;
  final String difficulty;
  final List<PlanStep> steps;

  ProjectPlan({
    this.notes = '',
    this.duration = '',
    this.budget = '',
    this.difficulty = '',
    List<PlanStep>? steps,
  }) : steps = steps ?? [];

  int get completedCount => steps.where((s) => s.done).length;

  double get progress =>
      steps.isEmpty ? 0 : completedCount / steps.length;

  Map<String, dynamic> toJson() => {
        'notes': notes,
        'duration': duration,
        'budget': budget,
        'difficulty': difficulty,
        'steps': steps.map((s) => s.toJson()).toList(),
      };

  factory ProjectPlan.fromJson(Map<String, dynamic> json) {
    // Les étapes doivent avoir des ids uniques : sinon cocher une étape les
    // coche toutes (cas des plans cloud, renvoyés sans id).
    final seen = <String>{};
    final steps = <PlanStep>[];
    for (final e in (json['steps'] as List?) ?? const []) {
      final map = jsonMap(e);
      if (map == null) continue;
      var step = PlanStep.fromJson(map);
      if (!seen.add(step.id)) {
        step = PlanStep.fromJson({...map, 'id': null});
        seen.add(step.id);
      }
      steps.add(step);
    }
    return ProjectPlan(
      notes: jsonString(json['notes']),
      duration: jsonString(json['duration']),
      budget: jsonString(json['budget']),
      difficulty: jsonString(json['difficulty']),
      steps: steps,
    );
  }
}

class InventionProject {
  String id;
  String title;
  String problem;
  String subtitle;
  String concept;
  String mechanism;
  List<String> materials;
  List<String> tools;
  String budget;
  String timeEstimate;
  int difficulty;
  String category;
  int score;
  List<String> tags;
  ProjectStatus status;
  final DateTime createdAt;
  DateTime updatedAt;
  ProjectPlan plan;
  bool starred;

  /// Fiche technique (cotes, nomenclature), créée à la demande.
  TechSheet? tech;

  /// Contraintes et décisions exprimées au fil de la conversation
  /// (« je n'ai que quatre boîtes », « sans soudure »…), envoyées à l'IA.
  List<String> designNotes;

  /// Aperçus artistiques générés, du plus ancien au plus récent.
  List<VisualVersion> visuals;

  /// États antérieurs du projet : rien n'est écrasé silencieusement.
  List<ProjectVersion> versions;

  /// Étape affichée en dernier dans le mode « On le fabrique ! ».
  int currentStep;

  InventionProject({
    required this.id,
    required this.title,
    this.problem = '',
    this.subtitle = '',
    this.concept = '',
    this.mechanism = '',
    List<String>? materials,
    List<String>? tools,
    this.budget = '',
    this.timeEstimate = '',
    this.difficulty = 2,
    this.category = '',
    this.score = 0,
    List<String>? tags,
    this.status = ProjectStatus.idea,
    DateTime? createdAt,
    DateTime? updatedAt,
    ProjectPlan? plan,
    this.starred = false,
    this.tech,
    List<String>? designNotes,
    List<VisualVersion>? visuals,
    List<ProjectVersion>? versions,
    this.currentStep = 0,
  })  : materials = materials ?? [],
        tools = tools ?? [],
        tags = tags ?? [],
        designNotes = designNotes ?? [],
        visuals = visuals ?? [],
        versions = versions ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        plan = plan ?? ProjectPlan();

  bool get hasPlan => plan.steps.isNotEmpty;

  double get buildProgress => plan.progress;

  void touch() => updatedAt = DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'problem': problem,
        'subtitle': subtitle,
        'concept': concept,
        'mechanism': mechanism,
        'materials': materials,
        'tools': tools,
        'budget': budget,
        'timeEstimate': timeEstimate,
        'difficulty': difficulty,
        'category': category,
        'score': score,
        'tags': tags,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'plan': plan.toJson(),
        'starred': starred,
        if (tech != null) 'tech': tech!.toJson(),
        if (designNotes.isNotEmpty) 'designNotes': designNotes,
        if (visuals.isNotEmpty) 'visuals': [for (final v in visuals) v.toJson()],
        if (versions.isNotEmpty) 'versions': [for (final v in versions) v.toJson()],
        if (currentStep > 0) 'currentStep': currentStep,
      };

  /// Contenu du projet sans son historique (versions) : instantané d'une
  /// version, et contexte envoyé à l'IA.
  Map<String, dynamic> toSnapshotJson() => toJson()..remove('versions');

  factory InventionProject.fromJson(Map<String, dynamic> json) =>
      InventionProject(
        id: jsonString(json['id']),
        title: jsonString(json['title']),
        problem: jsonString(json['problem']),
        subtitle: jsonString(json['subtitle']),
        concept: jsonString(json['concept']),
        mechanism: jsonString(json['mechanism']),
        materials: jsonStringList(json['materials']),
        tools: jsonStringList(json['tools']),
        budget: jsonString(json['budget']),
        timeEstimate: jsonString(json['timeEstimate']),
        difficulty: jsonInt(json['difficulty'], 2, min: 1, max: 5),
        category: jsonString(json['category']),
        score: jsonInt(json['score'], 0, min: 0, max: 100),
        tags: jsonStringList(json['tags']),
        status: ProjectStatus.fromName(jsonStringOrNull(json['status'])),
        createdAt: DateTime.tryParse(jsonString(json['createdAt'])) ?? DateTime.now(),
        updatedAt: DateTime.tryParse(jsonString(json['updatedAt'])) ?? DateTime.now(),
        plan: ProjectPlan.fromJson(jsonMap(json['plan']) ?? {}),
        starred: jsonBool(json['starred']),
        tech: jsonMap(json['tech']) == null ? null : TechSheet.fromJson(jsonMap(json['tech'])!),
        designNotes: jsonStringList(json['designNotes']),
        visuals: [
          if (json['visuals'] is List)
            for (final v in json['visuals'] as List)
              if (jsonMap(v) case final m?) VisualVersion.fromJson(m),
        ],
        versions: [
          if (json['versions'] is List)
            for (final v in json['versions'] as List)
              if (jsonMap(v) case final m?) ProjectVersion.fromJson(m),
        ],
        currentStep: jsonInt(json['currentStep'], 0, min: 0),
      );
}

/// Aperçu artistique d'un projet (image générée par un vrai fournisseur).
class VisualVersion {
  final String id;
  final String style;

  /// Modifications demandées depuis l'aperçu d'origine (« allonge le cou »…).
  final List<String> modifications;
  final String prompt;

  /// Image enregistrée dans le dossier de l'application.
  final String filePath;
  final String provider;
  final DateTime createdAt;

  VisualVersion({
    String? id,
    required this.style,
    List<String>? modifications,
    required this.prompt,
    required this.filePath,
    this.provider = '',
    DateTime? createdAt,
  })  : id = (id == null || id.isEmpty) ? _uuid.v4() : id,
        modifications = modifications ?? [],
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'style': style,
        'modifications': modifications,
        'prompt': prompt,
        'filePath': filePath,
        'provider': provider,
        'createdAt': createdAt.toIso8601String(),
      };

  factory VisualVersion.fromJson(Map<String, dynamic> json) => VisualVersion(
        id: jsonString(json['id']),
        style: jsonString(json['style']),
        modifications: jsonStringList(json['modifications']),
        prompt: jsonString(json['prompt']),
        filePath: jsonString(json['filePath']),
        provider: jsonString(json['provider']),
        createdAt: DateTime.tryParse(jsonString(json['createdAt'])),
      );
}

/// Instantané d'un projet avant une modification.
class ProjectVersion {
  final String id;
  final DateTime createdAt;

  /// Ce qui a déclenché la sauvegarde (« avant le plan de l'IA »…).
  final String reason;
  final Map<String, dynamic> snapshot;

  ProjectVersion({String? id, DateTime? createdAt, required this.reason, required this.snapshot})
      : id = (id == null || id.isEmpty) ? _uuid.v4() : id,
        createdAt = createdAt ?? DateTime.now();

  String get title => jsonString(snapshot['title']);

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'reason': reason,
        'snapshot': snapshot,
      };

  factory ProjectVersion.fromJson(Map<String, dynamic> json) => ProjectVersion(
        id: jsonString(json['id']),
        createdAt: DateTime.tryParse(jsonString(json['createdAt'])),
        reason: jsonString(json['reason']),
        snapshot: jsonMap(json['snapshot']) ?? {},
      );
}