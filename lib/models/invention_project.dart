import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'json_utils.dart';

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
  bool done;

  PlanStep({
    required this.id,
    required this.title,
    required this.detail,
    this.duration = '',
    this.safety = '',
    List<String>? materials,
    List<String>? tools,
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
  })  : materials = materials ?? [],
        tools = tools ?? [],
        tags = tags ?? [],
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
      };

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
      );
}