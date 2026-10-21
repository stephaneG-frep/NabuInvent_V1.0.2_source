import 'package:flutter/material.dart';

import '../models/idea_evaluation.dart';
import '../models/invention_project.dart';
import '../ai/ai_response.dart';
import 'common.dart';

class ProjectResponseCard extends StatelessWidget {
  final InventionProject project;
  final VoidCallback? onOpen;
  final VoidCallback? onPlan;
  final VoidCallback? onEvaluate;
  const ProjectResponseCard({
    super.key,
    required this.project,
    this.onOpen,
    this.onPlan,
    this.onEvaluate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = project;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: p.status.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(p.status.icon, color: p.status.color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(p.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                if (p.score > 0) ScoreRing(p.score, size: 32),
              ],
            ),
            const SizedBox(height: 10),
            if (p.problem.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(p.problem, style: theme.textTheme.bodySmall),
              ),
            if (p.mechanism.isNotEmpty)
              Text(
                'Principe : ${p.mechanism}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            const SizedBox(height: 10),
            if (p.hasPlan)
              Row(
                children: [
                  const Icon(Icons.task_alt, size: 15, color: Colors.green),
                  const SizedBox(width: 6),
                  Text(
                    '${p.plan.completedCount}/${p.plan.steps.length} étapes terminées',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onOpen != null)
                  FilledButton.tonalIcon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new, size: 17),
                    label: const Text('Voir le projet'),
                  ),
                if (onPlan != null)
                  OutlinedButton.icon(
                    onPressed: onPlan,
                    icon: const Icon(Icons.construction, size: 17),
                    label: const Text('Créer le plan'),
                  ),
                if (onEvaluate != null)
                  TextButton.icon(
                    onPressed: onEvaluate,
                    icon: const Icon(Icons.rule, size: 17),
                    label: const Text('Évaluer'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class EvaluationResponseCard extends StatelessWidget {
  final IdeaEvaluation evaluation;
  final VoidCallback? onCreateProject;
  const EvaluationResponseCard({
    super.key,
    required this.evaluation,
    this.onCreateProject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = evaluation;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.rule, color: Colors.orange),
                const SizedBox(width: 8),
                Text('Évaluation de l\'idée',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                ScoreRing(e.overall),
              ],
            ),
            const SizedBox(height: 12),
            ScoreBar(label: 'Originalité', value: e.originality, color: const Color(0xFFAB47BC)),
            const SizedBox(height: 6),
            ScoreBar(label: 'Faisabilité', value: e.feasibility, color: const Color(0xFF42A5F5)),
            const SizedBox(height: 6),
            ScoreBar(label: 'Impact', value: e.impact, color: const Color(0xFF66BB6A)),
            const SizedBox(height: 12),
            Text('Verdict : ${e.verdict}',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            if (onCreateProject != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onCreateProject,
                icon: const Icon(Icons.rocket_launch, size: 18),
                label: const Text('Transformer en projet'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SparkResponseCard extends StatelessWidget {
  final SparkContent spark;
  final VoidCallback? onInvent;
  final VoidCallback? onSave;
  const SparkResponseCard({
    super.key,
    required this.spark,
    this.onInvent,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 8),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome,
                    color: spark.challenge ? Colors.deepOrange : theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(spark.title.isNotEmpty ? spark.title : 'Étincelle',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            if (spark.domain.isNotEmpty || spark.material.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TagChips([
                  if (spark.domain.isNotEmpty) spark.domain,
                  if (spark.mechanism.isNotEmpty) spark.mechanism,
                  if (spark.material.isNotEmpty) spark.material,
                ]),
              ),
            if (spark.pitch.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(spark.pitch, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                if (onInvent != null)
                  FilledButton.tonalIcon(
                    onPressed: onInvent,
                    icon: const Icon(Icons.psychology, size: 17),
                    label: const Text('Inventer ça'),
                  ),
                if (onSave != null)
                  OutlinedButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.bookmark_add_outlined, size: 17),
                    label: const Text('Sauvegarder'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}