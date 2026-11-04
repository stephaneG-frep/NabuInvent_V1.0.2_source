import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../export/project_text.dart';
import '../models/invention_project.dart';
import 'common.dart';

/// Section repliable d'une fiche d'invention. Aucun défilement interne :
/// dépliée, elle prend toute la hauteur de son contenu.
class CollapsibleSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final String? badge;
  final bool initiallyExpanded;
  final Widget child;

  const CollapsibleSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.badge,
    this.initiallyExpanded = true,
  });

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(widget.icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                if (widget.badge != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(widget.badge!,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ),
                Icon(_open ? Icons.expand_less : Icons.expand_more, size: 20),
              ],
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.only(left: 26, bottom: 6),
            child: widget.child,
          ),
      ],
    );
  }
}

class _BulletList extends StatelessWidget {
  final List<String> items;
  final IconData icon;
  const _BulletList(this.items, {required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(icon, size: 14, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(item, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

class MaterialsSection extends StatelessWidget {
  final List<String> materials;
  final bool initiallyExpanded;
  const MaterialsSection(this.materials, {super.key, this.initiallyExpanded = true});

  @override
  Widget build(BuildContext context) {
    if (materials.isEmpty) return const SizedBox.shrink();
    return CollapsibleSection(
      title: 'Matériaux',
      icon: Icons.inventory_2_outlined,
      badge: '${materials.length}',
      initiallyExpanded: initiallyExpanded,
      child: _BulletList(materials, icon: Icons.circle),
    );
  }
}

class ToolsSection extends StatelessWidget {
  final List<String> tools;
  final bool initiallyExpanded;
  const ToolsSection(this.tools, {super.key, this.initiallyExpanded = true});

  @override
  Widget build(BuildContext context) {
    if (tools.isEmpty) return const SizedBox.shrink();
    return CollapsibleSection(
      title: 'Outils nécessaires',
      icon: Icons.handyman_outlined,
      badge: '${tools.length}',
      initiallyExpanded: initiallyExpanded,
      child: _BulletList(tools, icon: Icons.build_circle_outlined),
    );
  }
}

/// Budget, durée et difficulté sous forme de repères compacts.
class BudgetSection extends StatelessWidget {
  final String budget;
  final String time;
  final int? difficulty;
  const BudgetSection({super.key, this.budget = '', this.time = '', this.difficulty});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget fact(IconData icon, String label, Widget value) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: theme.textTheme.labelSmall),
                  value,
                ],
              ),
            ],
          ),
        );
    final items = [
      if (budget.trim().isNotEmpty)
        fact(Icons.euro, 'Budget estimé',
            Text(budget, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700))),
      if (time.trim().isNotEmpty)
        fact(Icons.schedule, 'Fabrication',
            Text(time, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700))),
      if (difficulty != null)
        fact(Icons.speed, 'Difficulté', DifficultyStars(difficulty!)),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: items);
  }
}

class ConstructionSteps extends StatelessWidget {
  final List<PlanStep> steps;
  final bool initiallyExpanded;
  final void Function(PlanStep step)? onToggle;

  const ConstructionSteps(this.steps,
      {super.key, this.initiallyExpanded = false, this.onToggle});

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final done = steps.where((s) => s.done).length;
    return CollapsibleSection(
      title: 'Étapes de réalisation',
      icon: Icons.format_list_numbered,
      badge: done > 0 ? '$done/${steps.length}' : '${steps.length}',
      initiallyExpanded: initiallyExpanded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: onToggle == null ? null : () => onToggle!(steps[i]),
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: steps[i].done
                          ? Colors.green
                          : theme.colorScheme.primaryContainer,
                      child: steps[i].done
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : Text('${i + 1}',
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].title.isEmpty ? 'Étape ${i + 1}' : steps[i].title,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (steps[i].duration.isNotEmpty)
                          Text(steps[i].duration,
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        if (steps[i].detail.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(steps[i].detail,
                                style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Avertissements de sécurité, toujours visibles (non repliables par défaut).
class SafetyWarnings extends StatelessWidget {
  final List<String> warnings;
  const SafetyWarnings(this.warnings, {super.key});

  @override
  Widget build(BuildContext context) {
    final unique = <String>{
      for (final w in warnings)
        if (w.trim().isNotEmpty) w.trim()
    }.toList();
    if (unique.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    const amber = Color(0xFFB26A00);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: amber.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.health_and_safety_outlined, size: 18, color: amber),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Conseils et précautions',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700, color: amber)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final w in unique)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.warning_amber_rounded, size: 14, color: amber),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(w, style: theme.textTheme.bodySmall)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Fiche d'invention complète, rendue à partir des données structurées
/// (jamais du JSON brut).
class InventionResultCard extends StatelessWidget {
  final InventionProject project;

  /// Plan à afficher s'il diffère de `project.plan` (réponse de type plan).
  final ProjectPlan? plan;
  final List<String> extraWarnings;
  final bool partial;
  final VoidCallback? onOpen;
  final VoidCallback? onPlan;
  final VoidCallback? onEvaluate;

  const InventionResultCard({
    super.key,
    required this.project,
    this.plan,
    this.extraWarnings = const [],
    this.partial = false,
    this.onOpen,
    this.onPlan,
    this.onEvaluate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = project;
    final steps = (plan != null && plan!.steps.isNotEmpty) ? plan!.steps : p.plan.steps;
    final warnings = [
      ...extraWarnings,
      for (final s in steps) s.safety,
    ];
    return Card(
      margin: const EdgeInsets.only(top: 8),
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.30),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.title.isEmpty ? 'Invention sans titre' : p.title,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      if (p.category.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(p.category,
                              style: theme.textTheme.labelMedium
                                  ?.copyWith(color: theme.colorScheme.primary)),
                        ),
                    ],
                  ),
                ),
                if (p.score > 0) ScoreRing(p.score, size: 34),
                IconButton(
                  tooltip: 'Copier la fiche',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: projectToPlainText(p, plan: plan)));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Fiche copiée.')));
                  },
                ),
              ],
            ),
            if (partial)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Réponse incomplète : certaines sections peuvent manquer.',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.error)),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.problem.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(p.problem, style: theme.textTheme.bodyMedium),
                  ],
                  if (p.concept.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(p.concept, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
                  ],
                  if (p.mechanism.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Principe : ${p.mechanism}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant, height: 1.4)),
                  ],
                  const SizedBox(height: 10),
                  BudgetSection(
                    budget: p.budget,
                    time: p.timeEstimate,
                    difficulty: p.difficulty,
                  ),
                  const SizedBox(height: 4),
                  MaterialsSection(p.materials),
                  ToolsSection(p.tools, initiallyExpanded: false),
                  ConstructionSteps(steps, initiallyExpanded: plan != null),
                  SafetyWarnings(warnings),
                  const SizedBox(height: 8),
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
                      if (onPlan != null && steps.isEmpty)
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
          ],
        ),
      ),
    );
  }
}
