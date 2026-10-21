import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/backlog_idea.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'project_detail_screen.dart';

class BacklogScreen extends StatefulWidget {
  const BacklogScreen({super.key});

  @override
  State<BacklogScreen> createState() => _BacklogScreenState();
}

class _BacklogScreenState extends State<BacklogScreen> {
  bool showArchived = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    var ideas = app.data.backlog
        .where((b) => showArchived ? b.archived : !b.archived)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carnet d\'idées'),
        actions: [
          IconButton(
            tooltip: 'Ajouter une idée',
            onPressed: () => _addIdea(context),
            icon: const Icon(Icons.add_box_outlined),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Actives')),
                      ButtonSegment(value: true, label: Text('Archivées')),
                    ],
                    selected: {showArchived},
                    onSelectionChanged: (s) => setState(() => showArchived = s.first),
                    showSelectedIcon: false,
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${ideas.length}', style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
          ),
        ),
      ),
      body: ideas.isEmpty
          ? EmptyState(
              icon: Icons.lightbulb_outline,
              title: 'Carnet vide',
              subtitle:
                  'Capture vite une idée avant qu\'elle ne s\'envole — tu la '
                  'développeras plus tard avec l\'agent.',
              action: FilledButton.icon(
                onPressed: () => _addIdea(context),
                icon: const Icon(Icons.add),
                label: const Text('Capturer une idée'),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              itemCount: ideas.length,
              itemBuilder: (context, i) {
                final idea = ideas[i];
                return Dismissible(
                  key: ValueKey(idea.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(showArchived ? Icons.delete_outline : Icons.archive_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  onDismissed: (_) {
                    if (showArchived) {
                      context.read<AppState>().deleteBacklogIdea(idea.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Idée supprimée.')),
                      );
                    } else {
                      context
                          .read<AppState>()
                          .setBacklogArchived(idea.id, true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Idée archivée.')),
                      );
                    }
                  },
                  child: _IdeaCard(
                    idea: idea,
                    onTap: () => _openSheet(context, idea),
                    projectTitle: app.data.projectById(idea.convertedProjectId)?.title,
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addIdea(context),
        icon: const Icon(Icons.add),
        label: const Text('Idée'),
      ),
    );
  }

  void _addIdea(BuildContext context) {
    final title = TextEditingController();
    final note = TextEditingController();
    final tags = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Capturer une idée'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'L\'idée, en un titre'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Détail (facultatif)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tags,
                decoration: const InputDecoration(
                    labelText: 'Catégories séparées par des virgules'),
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
              final t = title.text.trim();
              if (t.isEmpty) return;
              final tagList = tags.text
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
              context
                  .read<AppState>()
                  .addBacklogIdea(t, note: note.text.trim(), tags: tagList);
              Navigator.of(context).pop();
            },
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  void _openSheet(BuildContext context, BacklogIdea idea) {
    final app = context.read<AppState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(idea.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (idea.note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(idea.note, style: Theme.of(context).textTheme.bodyMedium),
              ],
              const SizedBox(height: 8),
              Text(
                'Capturée le ${DateFormat('d MMM yyyy').format(idea.createdAt)}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              if (idea.tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                TagChips(idea.tags),
              ],
              const SizedBox(height: 18),
              if (idea.isConverted)
                Row(
                  children: [
                    const Icon(Icons.check_circle, size: 18, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text('Déjà transformée en projet'),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          final id = context
                              .read<AppState>()
                              .promoteBacklogToProject(idea.id);
                          Navigator.of(context).pop();
                          if (id.isNotEmpty) {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => ProjectDetailScreen(projectId: id)));
                          }
                        },
                        icon: const Icon(Icons.rocket_launch),
                        label: const Text('Promouvoir en projet'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        app.setBacklogArchived(idea.id, !idea.archived);
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.archive_outlined),
                      label: Text(idea.archived ? 'Désarchiver' : 'Archiver'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdeaCard extends StatelessWidget {
  final BacklogIdea idea;
  final VoidCallback onTap;
  final String? projectTitle;
  const _IdeaCard({required this.idea, required this.onTap, this.projectTitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    idea.archived
                        ? Icons.archive_outlined
                        : idea.isConverted
                            ? Icons.check_circle
                            : Icons.lightbulb_outline,
                    size: 18,
                    color: idea.archived
                        ? theme.colorScheme.outline
                        : idea.isConverted
                            ? Colors.green
                            : const Color(0xFFF2B950),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(idea.title,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  Text(DateFormat('d MMM').format(idea.createdAt),
                      style: theme.textTheme.labelSmall),
                ],
              ),
              if (idea.note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(idea.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall),
              ],
              if (projectTitle != null) ...[
                const SizedBox(height: 6),
                Text('→ Projet : $projectTitle', style: theme.textTheme.labelSmall),
              ],
              if (idea.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                TagChips(idea.tags),
              ],
            ],
          ),
        ),
      ),
    );
  }
}