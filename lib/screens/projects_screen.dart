import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/invention_project.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/project_card.dart';
import 'project_detail_screen.dart';

const _uuid = Uuid();

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  ProjectStatus? filter;
  String query = '';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    var list = [...app.data.projects]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (filter != null) {
      list = list.where((p) => p.status == filter).toList();
    }
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      list = list
          .where((p) =>
              p.title.toLowerCase().contains(q) ||
              p.problem.toLowerCase().contains(q) ||
              p.tags.any((t) => t.toLowerCase().contains(q)))
          .toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final text = await showSearch<String>(
                context: context,
                delegate: _ProjectSearchDelegate(list),
              );
              if (text != null) setState(() => query = text);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                _filterChip(context, null, 'Tous', Icons.apps),
                for (final s in ProjectStatus.values)
                  _filterChip(context, s, s.label, s.icon),
              ],
            ),
          ),
          Expanded(
            child: app.data.projects.isEmpty
                ? EmptyState(
                    icon: Icons.folder_open,
                    title: 'Aucun projet',
                    subtitle:
                        'Demande à l\'agent d\'inventer quelque chose, ou crée '
                        'manuellement un projet à partir d\'une idée.',
                    action: FilledButton.icon(
                      onPressed: () => _createManually(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Nouveau projet'),
                    ),
                  )
                : list.isEmpty
                    ? EmptyState(
                        icon: Icons.filter_alt_off,
                        title: 'Rien ici',
                        subtitle: 'Aucun projet ne correspond à ce filtre.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final p = list[i];
                          return ProjectCard(
                            project: p,
                            onTap: () => _open(context, p.id),
                            onStar: () => app.toggleStar(p.id),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createManually(context),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau projet'),
      ),
    );
  }

  Widget _filterChip(BuildContext context, ProjectStatus? s, String label, IconData icon) {
    final active = filter == s;
    final color = s?.color ?? Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: active,
        showCheckmark: false,
        avatar: Icon(icon, size: 16, color: active ? color : null),
        label: Text(label),
        onSelected: (_) => setState(() => filter = s),
      ),
    );
  }

  void _open(BuildContext context, String id) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: id)),
    );
  }

  void _createManually(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _CreateProjectDialog(),
    );
  }
}

class _CreateProjectDialog extends StatefulWidget {
  const _CreateProjectDialog();

  @override
  State<_CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<_CreateProjectDialog> {
  final _title = TextEditingController();
  final _problem = TextEditingController();
  final _category = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _problem.dispose();
    _category.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau projet'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nom de l\'invention'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _problem,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Problème ou idée (facultatif)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _category,
              decoration: const InputDecoration(
                  labelText: 'Catégorie (maison, jardin, atelier…)'),
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
          onPressed: _save,
          child: const Text('Créer'),
        ),
      ],
    );
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final app = context.read<AppState>();
    final project = InventionProject(
      id: _uuid.v4(),
      title: title,
      problem: _problem.text.trim(),
      subtitle: _problem.text.trim(),
      category: _category.text.trim(),
    );
    app.createProject(project);
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: project.id)),
    );
  }
}

class _ProjectSearchDelegate extends SearchDelegate<String> {
  final List<InventionProject> source;
  _ProjectSearchDelegate(this.source);

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.close),
        ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        onPressed: () => close(context, ''),
        icon: const Icon(Icons.arrow_back),
      );

  @override
  Widget buildResults(BuildContext context) {
    final q = query.toLowerCase();
    final results = source
        .where((p) =>
            p.title.toLowerCase().contains(q) ||
            p.problem.toLowerCase().contains(q))
        .toList();
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, i) {
        final p = results[i];
        return ListTile(
          leading: Icon(p.status.icon, color: p.status.color),
          title: Text(p.title),
          subtitle: Text(p.category.isEmpty ? p.status.label : p.category),
          onTap: () {
            close(context, p.title);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProjectDetailScreen(projectId: p.id),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final q = query.toLowerCase();
    final results = source
        .where((p) =>
            p.title.toLowerCase().contains(q) ||
            p.problem.toLowerCase().contains(q))
        .toList();
    return ListView(
      children: [
        for (final p in results)
          ListTile(
            leading: Icon(p.status.icon, color: p.status.color),
            title: Text(p.title),
            subtitle: Text(p.status.label),
            onTap: () async {
              close(context, '');
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProjectDetailScreen(projectId: p.id),
                ),
              );
            },
          ),
      ],
    );
  }
}