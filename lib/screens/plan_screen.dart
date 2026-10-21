import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/invention_project.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

const _uuid = Uuid();

class PlanScreen extends StatefulWidget {
  final String projectId;
  const PlanScreen({super.key, required this.projectId});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  void _toggle(String stepId) {
    context.read<AppState>().toggleStepDone(widget.projectId, stepId);
  }

  void _addStep() {
    final title = TextEditingController();
    final detail = TextEditingController();
    final duration = TextEditingController();
    final safety = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nouvelle étape'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Titre de l\'étape'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: detail,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Déroulé (facultatif)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: duration,
                decoration: const InputDecoration(labelText: 'Durée (ex : 45 min)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: safety,
                decoration: const InputDecoration(labelText: 'Sécurité (facultatif)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isEmpty) return;
              final app = context.read<AppState>();
              final p = app.data.projectById(widget.projectId);
              if (p == null) return;
              final plan = ProjectPlan(
                notes: p.plan.notes,
                duration: p.plan.duration,
                budget: p.plan.budget,
                difficulty: p.plan.difficulty,
                steps: [
                  ...p.plan.steps,
                  PlanStep(
                    id: _uuid.v4(),
                    title: title.text.trim(),
                    detail: detail.text.trim(),
                    duration: duration.text.trim(),
                    safety: safety.text.trim(),
                  ),
                ],
              );
              app.updatePlan(widget.projectId, plan);
              Navigator.of(context).pop();
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _editStep(PlanStep step) {
    final title = TextEditingController(text: step.title);
    final detail = TextEditingController(text: step.detail);
    final duration = TextEditingController(text: step.duration);
    final safety = TextEditingController(text: step.safety);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Modifier l\'étape'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Titre'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: detail,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Déroulé'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: duration,
                decoration: const InputDecoration(labelText: 'Durée'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: safety,
                decoration: const InputDecoration(labelText: 'Sécurité'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final app = context.read<AppState>();
              final p = app.data.projectById(widget.projectId);
              if (p == null) return;
              app.updatePlan(widget.projectId, ProjectPlan(
                notes: p.plan.notes,
                duration: p.plan.duration,
                budget: p.plan.budget,
                difficulty: p.plan.difficulty,
                steps: [
                  for (final s in p.plan.steps)
                    s.id == step.id
                        ? PlanStep(
                            id: s.id,
                            title: title.text.trim().isEmpty ? s.title : title.text.trim(),
                            detail: detail.text.trim(),
                            duration: duration.text.trim(),
                            safety: safety.text.trim(),
                            done: s.done,
                          )
                        : s,
                ],
              ));
              Navigator.of(context).pop();
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _removeStep(PlanStep step) {
    final app = context.read<AppState>();
    final p = app.data.projectById(widget.projectId);
    if (p == null) return;
    app.updatePlan(widget.projectId, ProjectPlan(
      notes: p.plan.notes,
      duration: p.plan.duration,
      budget: p.plan.budget,
      difficulty: p.plan.difficulty,
      steps: [for (final s in p.plan.steps) if (s.id != step.id) s],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.data.projectById(widget.projectId)!;
    final plan = p.plan;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Plan de construction'),
            if (p.title.isNotEmpty)
              Text(p.title,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
      body: plan.steps.isEmpty
          ? EmptyState(
              icon: Icons.construction,
              title: 'Aucune étape',
              subtitle:
                  'Génère un plan avec l\'IA dans le Studio, ou ajoute tes étapes à la main.',
              action: FilledButton.icon(
                onPressed: _addStep,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une étape'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.track_changes, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              '${plan.completedCount}/${plan.steps.length} étapes terminées',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            Text('${(plan.progress * 100).round()} %',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(value: plan.progress, minHeight: 9),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 14,
                          runSpacing: 8,
                          children: [
                            if (plan.duration.isNotEmpty)
                              MetricLabel(Icons.schedule, plan.duration),
                            if (plan.budget.isNotEmpty) MetricLabel(Icons.euro, plan.budget),
                            if (plan.difficulty.isNotEmpty)
                              MetricLabel(Icons.workspace_premium, plan.difficulty),
                          ],
                        ),
                        if (plan.notes.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(plan.notes,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < plan.steps.length; i++)
                  _StepTile(
                    index: i + 1,
                    step: plan.steps[i],
                    onToggle: () => _toggle(plan.steps[i].id),
                    onEdit: () => _editStep(plan.steps[i]),
                    onDelete: () => _removeStep(plan.steps[i]),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addStep,
        icon: const Icon(Icons.add),
        label: const Text('Étape'),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final int index;
  final PlanStep step;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _StepTile({
    required this.index,
    required this.step,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(value: step.done, onChanged: (_) => onToggle()),
            Expanded(
              child: InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$index',
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(step.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  decoration: step.done ? TextDecoration.lineThrough : null,
                                  color: step.done
                                      ? theme.colorScheme.onSurfaceVariant
                                      : null,
                                )),
                          ),
                        ],
                      ),
                      if (step.detail.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(step.detail, style: theme.textTheme.bodySmall),
                      ],
                      if (step.duration.isNotEmpty || step.safety.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            if (step.duration.isNotEmpty)
                              MetricLabel(Icons.schedule, step.duration),
                            if (step.safety.isNotEmpty)
                              MetricLabel(Icons.shield_outlined, step.safety),
                          ],
                        ),
                      ],
                      if (step.materials.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final m in step.materials)
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(m, style: theme.textTheme.labelSmall),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 19),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}