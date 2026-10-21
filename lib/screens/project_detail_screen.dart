import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/invention_project.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'journal_screen.dart';
import 'plan_screen.dart';
import 'studio_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.data.projectById(widget.projectId);
    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.folder_delete_outlined,
          title: 'Projet introuvable',
          subtitle: 'Ce projet a peut-être été supprimé.',
        ),
      );
    }
    final projectNotes = app
        .data
        .journal
        .where((j) => j.projectId == p.id)
        .toList()
        .reversed
        .take(3)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projet'),
        actions: [
          IconButton(
            tooltip: p.starred ? 'Retirer des favoris' : 'Ajouter aux favoris',
            onPressed: () => app.toggleStar(p.id),
            icon: Icon(
              p.starred ? Icons.star : Icons.star_border,
              color: p.starred ? const Color(0xFFF6BF26) : null,
            ),
          ),
          IconButton(
            tooltip: 'Supprimer',
            onPressed: () => _confirmDelete(context, p),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          _HeaderCard(project: p),
          const SizedBox(height: 16),
          _Section('Le problème à résoudre', [
            _readable(p.problem.isEmpty ? p.subtitle : p.problem,
                fallback: 'Aucune description du problème.'),
          ]),
          const SizedBox(height: 14),
          _Section('Le concept', [
            _readable(p.concept,
                fallback: 'Concept à enrichir — demande à l\'agent de le détailler.'),
            if (p.mechanism.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Principe de fonctionnement : ${p.mechanism}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
          ]),
          const SizedBox(height: 14),
          _Section(
            'Matériaux & outils',
            [
              if (p.materials.isEmpty)
                Text('Aucun matériau listé.',
                    style: Theme.of(context).textTheme.bodySmall)
              else
                TagChips(p.materials),
              const SizedBox(height: 10),
              if (p.tools.isNotEmpty) ...[
                const SectionHeader('Outillage', padding: EdgeInsets.only(bottom: 6)),
                TagChips(p.tools),
              ],
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            'Plan de construction',
            [
              if (!p.hasPlan)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Pas encore de plan. Génère des étapes avec l\'IA ou construis le tien.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                )
              else ...[
                _ProgressBlock(project: p),
                const SizedBox(height: 10),
                for (final s in p.plan.steps.take(4))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _MiniStepTile(step: s, onTap: () => _openPlan(context, p)),
                  ),
                if (p.plan.steps.length > 4)
                  Text('+ ${p.plan.steps.length - 4} autres étapes…',
                      style: Theme.of(context).textTheme.labelMedium),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _openPlan(context, p),
                    icon: const Icon(Icons.build_outlined),
                    label: Text(p.hasPlan ? 'Ouvrir le plan' : 'Créer/ouvrir le plan'),
                  ),
                  if (!p.hasPlan)
                    FilledButton.icon(
                      onPressed: () => _askPlan(context, p),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Générer avec l\'IA'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            'Journal du projet',
            [
              if (projectNotes.isEmpty)
                Text('Aucune note pour ce projet.',
                    style: Theme.of(context).textTheme.bodySmall)
              else
                for (final n in projectNotes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '• ${n.text}  (${DateFormat('d MMM').format(n.createdAt)})',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _addNote(context, p),
                    icon: const Icon(Icons.add_comment_outlined, size: 18),
                    label: const Text('Ajouter une note'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => JournalScreen(projectId: p.id),
                        ),
                      );
                    },
                    icon: const Icon(Icons.menu_book_outlined, size: 18),
                    label: const Text('Tout le journal'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: _StatusButton(project: p),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StudioScreen(seedProjectId: p.id),
                    ),
                  ).then((_) {});
                },
                icon: const Icon(Icons.psychology),
                label: const Text('Parler au Studio'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _readable(String text, {required String fallback}) {
    return Text(
      text.trim().isEmpty ? fallback : text,
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }

  void _openPlan(BuildContext context, InventionProject p) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlanScreen(projectId: p.id)),
    );
  }

  void _askPlan(BuildContext context, InventionProject p) {
    // La demande part immédiatement, sur ce projet ; le Studio affiche la
    // réponse dès qu'elle arrive.
    context.read<AppState>().askAi(
        'Élabore le plan de construction détaillé de ce projet, étape par étape.',
        activeProjectId: p.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudioScreen(seedProjectId: p.id),
      ),
    );
  }

  void _addNote(BuildContext context, InventionProject p) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Note de journal'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Ta pensée du moment…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<AppState>().addJournalEntry(controller.text.trim(),
                    projectId: p.id);
              }
              Navigator.of(context).pop();
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, InventionProject p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce projet ?'),
        content: Text('« ${p.title} » sera définitivement supprimé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              context.read<AppState>().deleteProject(p.id);
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section(this.title, this.children);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final InventionProject project;
  const _HeaderCard({required this.project});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = project;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            p.status.color.withValues(alpha: 0.22),
            p.status.color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.status.color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(p.title,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              if (p.score > 0) ScoreRing(p.score),
            ],
          ),
          if (p.category.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(p.category,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(p.status),
              if (p.difficulty > 0) DifficultyStars(p.difficulty),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              if (p.budget.isNotEmpty) MetricLabel(Icons.euro, p.budget),
              if (p.timeEstimate.isNotEmpty) MetricLabel(Icons.schedule, p.timeEstimate),
              if (p.hasPlan)
                MetricLabel(Icons.task_alt,
                    '${p.plan.completedCount}/${p.plan.steps.length} étapes'),
            ],
          ),
          if (p.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            TagChips(p.tags),
          ],
        ],
      ),
    );
  }
}

class _ProgressBlock extends StatelessWidget {
  final InventionProject project;
  const _ProgressBlock({required this.project});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = project;
    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: p.buildProgress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 10),
        Text('${(p.buildProgress * 100).round()} %',
            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _MiniStepTile extends StatelessWidget {
  final PlanStep step;
  final VoidCallback onTap;
  const _MiniStepTile({required this.step, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              step.done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: step.done ? Colors.green : Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(step.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        decoration: step.done ? TextDecoration.lineThrough : null,
                      )),
            ),
            if (step.duration.isNotEmpty)
              Text(step.duration,
                  style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  final InventionProject project;
  const _StatusButton({required this.project});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final app = context.read<AppState>();
        final choice = await showModalBottomSheet<ProjectStatus>(
          context: context,
          builder: (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('Passer le projet à…', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                for (final s in ProjectStatus.values)
                  ListTile(
                    leading: Icon(s.icon, color: s.color),
                    title: Text(s.label),
                    trailing: s == project.status ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.of(context).pop(s),
                  ),
              ],
            ),
          ),
        );
        if (choice != null) {
          app.setProjectStatus(project.id, choice);
        }
      },
      icon: Icon(project.status.icon, color: project.status.color),
      label: Text(project.status.label),
    );
  }
}