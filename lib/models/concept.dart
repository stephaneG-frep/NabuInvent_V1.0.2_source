import 'package:uuid/uuid.dart';

import 'invention_project.dart';
import 'json_utils.dart';

const _uuid = Uuid();

/// Une variante de concept proposée par l'atelier (ex. « Héron minimaliste »).
///
/// Les dimensions, durées et budgets sont des **ordres de grandeur indicatifs**
/// proposés par l'IA : ils ne sont jamais présentés comme mesurés.
class InventionConcept {
  final String id;

  /// Objet concerné, pour regrouper les variantes (ex. « Canard », « Héron »).
  final String subject;
  final String name;
  final String description;
  final String style;
  final List<String> materials;
  final String dimensions;
  final int difficulty;
  final String time;
  final String budget;
  final List<String> advantages;
  final List<String> constraints;

  /// Pourquoi l'IA propose ce concept (mode « inventeur autonome »).
  final String why;

  /// Faisabilité estimée avec les ressources disponibles, 0–100 (0 = inconnue).
  final int feasibility;

  InventionConcept({
    String? id,
    this.subject = '',
    required this.name,
    this.description = '',
    this.style = '',
    List<String>? materials,
    this.dimensions = '',
    this.difficulty = 2,
    this.time = '',
    this.budget = '',
    List<String>? advantages,
    List<String>? constraints,
    this.why = '',
    this.feasibility = 0,
  })  : id = (id == null || id.isEmpty) ? _uuid.v4() : id,
        materials = materials ?? [],
        advantages = advantages ?? [],
        constraints = constraints ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'name': name,
        'description': description,
        'style': style,
        'materials': materials,
        'dimensions': dimensions,
        'difficulty': difficulty,
        'time': time,
        'budget': budget,
        'advantages': advantages,
        'constraints': constraints,
        if (why.isNotEmpty) 'why': why,
        if (feasibility > 0) 'feasibility': feasibility,
      };

  factory InventionConcept.fromJson(Map<String, dynamic> json) => InventionConcept(
        id: jsonString(json['id']),
        subject: jsonString(json['subject']),
        name: jsonString(json['name'], jsonString(json['title'], 'Concept')),
        description: jsonString(json['description']),
        style: jsonString(json['style']),
        materials: jsonStringList(json['materials']),
        dimensions: jsonString(json['dimensions']),
        difficulty: jsonInt(json['difficulty'], 2, min: 1, max: 5),
        time: jsonString(json['time'], jsonString(json['timeEstimate'])),
        budget: jsonString(json['budget']),
        advantages: jsonStringList(json['advantages']),
        constraints: jsonStringList(json['constraints']),
        why: jsonString(json['why']),
        feasibility: jsonInt(json['feasibility'], 0, min: 0, max: 100),
      );

  /// Transforme le concept choisi en projet, sans appel à l'IA.
  InventionProject toProject() => InventionProject(
        id: _uuid.v4(),
        title: name,
        subtitle: [if (subject.isNotEmpty) subject, if (style.isNotEmpty) style].join(' · '),
        problem: why,
        concept: description,
        materials: List.of(materials),
        budget: budget,
        timeEstimate: time,
        difficulty: difficulty,
        category: subject.isNotEmpty ? subject : style,
        tags: [if (style.isNotEmpty) style, 'concept'],
      );
}

/// Regroupe des concepts par objet, dans l'ordre d'apparition.
Map<String, List<InventionConcept>> groupConceptsBySubject(List<InventionConcept> concepts) {
  final groups = <String, List<InventionConcept>>{};
  for (final c in concepts) {
    groups.putIfAbsent(c.subject.isEmpty ? 'Propositions' : c.subject, () => []).add(c);
  }
  return groups;
}
