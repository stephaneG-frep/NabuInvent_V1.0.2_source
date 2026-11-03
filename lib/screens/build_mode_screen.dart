import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/invention_project.dart';
import '../state/app_state.dart';
import '../tech/safety_checker.dart';
import '../widgets/common.dart';
import '../widgets/invention_sections.dart';
import '../widgets/rich_message.dart';

/// « On le fabrique ! » : fabrication guidée, une étape par page, progression
/// sauvegardée, aide pédagogique de l'IA sur l'étape en cours.
class BuildModeScreen extends StatefulWidget {
  final String projectId;
  const BuildModeScreen({super.key, required this.projectId});

  @override
  State<BuildModeScreen> createState() => _BuildModeScreenState();
}

class _BuildModeScreenState extends State<BuildModeScreen> {
  late final PageController _pages;
  int _index = 0;

  static const _help = [
    (Icons.child_care, 'Plus simplement', 'Explique-moi cette étape plus simplement, pas à pas.'),
    (Icons.handyman_outlined, 'Sans cet outil', 'Comment faire cette étape sans l\'outil prévu, avec un outil plus courant ?'),
    (Icons.alt_route, 'Autre méthode', 'Montre-moi une autre méthode pour réaliser cette étape.'),
    (Icons.help_outline, 'Pourquoi ?', 'Pourquoi cette fixation ou cette façon de faire à cette étape ?'),
  ];

  @override
  void initState() {
    super.initState();
    final p = context.read<AppState>().data.projectById(widget.projectId);
    final count = p?.plan.steps.length ?? 0;
    _index = count == 0 ? 0 : (p!.currentStep).clamp(0, count - 1);
    _pages = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _ask(InventionProject p, PlanStep step, int index, String question) async {
    final app = context.read<AppState>();
    final request = 'Étape ${index + 1} du plan, « ${step.title} » : ${step.detail}\n$question';
    final future = app.askAi(request, activeProjectId: p.id);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (ctx, scroll) => FutureBuilder(
          future: future,
          builder: (ctx, snap) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
            children: [
              Text(question, style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (!snap.hasData)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              else
                SelectionArea(child: RichMessage(snap.data!.message)),
              const SizedBox(height: 8),
              Text('Cette réponse est aussi enregistrée dans le Studio.',
                  style: Theme.of(ctx).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);
    final p = app.data.projectById(widget.projectId);
    if (p == null) return const Scaffold(body: Center(child: Text('Projet introuvable.')));
    final steps = p.plan.steps;
    if (steps.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('On le fabrique !')),
        body: const EmptyState(
          icon: Icons.construction,
          title: 'Pas encore de plan',
          subtitle: 'Demande d\'abord un plan de construction depuis la fiche du projet.',
        ),
      );
    }
    final done = p.plan.completedCount;
    final safety = SafetyChecker.checkProject(p);

    return Scaffold(
      appBar: AppBar(
        title: const Text('On le fabrique !'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Expanded(child: LinearProgressIndicator(value: done / steps.length, minHeight: 6)),
                const SizedBox(width: 10),
                Text('$done/${steps.length}', style: theme.textTheme.labelMedium),
              ],
            ),
          ),
        ),
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: steps.length,
        onPageChanged: (i) {
          setState(() => _index = i);
          app.setCurrentStep(p.id, i);
        },
        itemBuilder: (context, i) {
          final s = steps[i];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text('Étape ${i + 1} sur ${steps.length}', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(s.title.isEmpty ? 'Étape ${i + 1}' : s.title,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              if (s.duration.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    const Icon(Icons.schedule, size: 16),
                    const SizedBox(width: 4),
                    Text(s.duration),
                  ]),
                ),
              if (s.objective.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Block(icon: Icons.flag_outlined, title: 'Objectif', child: Text(s.objective)),
              ],
              if (s.materials.isNotEmpty) MaterialsSection(s.materials),
              if (s.tools.isNotEmpty) ToolsSection(s.tools),
              const SizedBox(height: 8),
              _Block(
                icon: Icons.menu_book_outlined,
                title: 'Instructions',
                child: SelectionArea(
                    child: RichMessage(s.detail.isEmpty ? 'Pas de description pour cette étape.' : s.detail)),
              ),
              if (s.dimensions.isNotEmpty)
                _Block(icon: Icons.straighten, title: 'Cotes', child: Text(s.dimensions)),
              if (s.tips.isNotEmpty)
                _Block(icon: Icons.tips_and_updates_outlined, title: 'Conseils', child: Text(s.tips)),
              SafetyWarnings([
                s.safety,
                // Les rappels généraux sont montrés à la première étape.
                if (i == 0) ...safety.map((f) => f.text),
              ]),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: s.done,
                onChanged: (_) => app.toggleStepDone(p.id, s.id),
                title: const Text('Terminé', style: TextStyle(fontWeight: FontWeight.w700)),
                controlAffinity: ListTileControlAffinity.leading,
                tileColor: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              const SizedBox(height: 12),
              Text('Besoin d\'aide sur cette étape ?', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (icon, label, question) in _help)
                    ActionChip(
                      avatar: Icon(icon, size: 16),
                      label: Text(label),
                      onPressed: app.aiThinking ? null : () => _ask(p, s, i, question),
                    ),
                ],
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _index == 0
                    ? null
                    : () => _pages.previousPage(
                        duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                icon: const Icon(Icons.chevron_left),
                label: const Text('Précédente'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _index >= steps.length - 1
                    ? null
                    : () => _pages.nextPage(
                        duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                icon: const Icon(Icons.chevron_right),
                label: const Text('Suivante'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _Block({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          Padding(padding: const EdgeInsets.only(left: 24), child: child),
        ],
      ),
    );
  }
}
