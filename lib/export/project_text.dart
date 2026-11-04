import '../models/invention_project.dart';

/// Version texte lisible d'un projet : copie dans le presse-papiers, partage,
/// base des exports.
String projectToPlainText(InventionProject p, {ProjectPlan? plan}) {
  final b = StringBuffer()..writeln(p.title.toUpperCase());
  void section(String title, String body) {
    if (body.trim().isEmpty) return;
    b
      ..writeln()
      ..writeln(title)
      ..writeln(body.trim());
  }

  void list(String title, List<String> items) {
    if (items.isEmpty) return;
    b
      ..writeln()
      ..writeln(title);
    for (final i in items) {
      b.writeln('- $i');
    }
  }

  section('Problème', p.problem);
  section('Concept', p.concept);
  section('Principe', p.mechanism);
  list('Matériaux', p.materials);
  list('Outils', p.tools);
  final facts = [
    if (p.budget.isNotEmpty) 'Budget : ${p.budget}',
    if (p.timeEstimate.isNotEmpty) 'Durée : ${p.timeEstimate}',
    'Difficulté : ${p.difficulty}/5',
  ];
  section('Repères', facts.join('\n'));

  final steps = (plan ?? p.plan).steps;
  if (steps.isNotEmpty) {
    b
      ..writeln()
      ..writeln('Étapes');
    for (var i = 0; i < steps.length; i++) {
      final s = steps[i];
      b.writeln('${i + 1}. ${s.title}${s.duration.isNotEmpty ? ' (${s.duration})' : ''}');
      if (s.detail.isNotEmpty) b.writeln('   ${s.detail}');
      if (s.safety.isNotEmpty) b.writeln('   ⚠ ${s.safety}');
    }
  }
  return b.toString().trimRight();
}
