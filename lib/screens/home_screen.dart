import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/invention_project.dart';
import '../state/app_state.dart';
import '../state/tab_bus.dart';
import '../widgets/common.dart';
import '../widgets/project_card.dart';
import 'backlog_screen.dart';
import 'journal_screen.dart';
import 'project_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);
    final recent = [...app.data.projects]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final recentList = recent.take(4).toList();
    final latestNotes = app.journalFor(null).take(3).toList();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {},
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Salut, inventeur !',
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text('NabuInvent AI · ${app.aiStatusLabel}',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.lightbulb_rounded,
                        color: theme.colorScheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _StatCard(
                    value: app.data.activeProjects,
                    label: 'projets actifs',
                    icon: Icons.rocket_launch_outlined,
                    onTap: () {
                      context.read<TabBus>().go(1);
                    },
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    value: app.data.builtProjects,
                    label: 'construits',
                    icon: Icons.emoji_events_outlined,
                    onTap: () {
                      context.read<TabBus>().go(1);
                    },
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    value: app.data.backlog
                        .where((b) => !b.archived && !b.isConverted)
                        .length,
                    label: 'idées en attente',
                    icon: Icons.lightbulb_outline,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BacklogScreen()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const SectionHeader('Actions rapides'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.psychology,
                      label: 'Studio',
                      detail: 'Parler à l\'agent',
                      onTap: () => context.read<TabBus>().go(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.auto_awesome,
                      label: 'Étincelles',
                      detail: 'Idées créatives',
                      onTap: () => context.read<TabBus>().go(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.note_add_outlined,
                      label: 'Journal',
                      detail: 'Mes pensées',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const JournalScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SectionHeader(
                'Projets récents',
                trailing: TextButton(
                  onPressed: () => context.read<TabBus>().go(1),
                  child: const Text('Tout voir'),
                ),
              ),
              const SizedBox(height: 6),
              if (recentList.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Icon(Icons.folder_open,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Aucun projet encore. Va dans le Studio et demande : '
                            '« invente quelque chose pour... »',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...[
                  for (final p in recentList)
                    ProjectCard(
                      project: p,
                      onTap: () => _openProject(context, p),
                      onStar: () => app.toggleStar(p.id),
                    ),
                ],
              const SizedBox(height: 20),
              const SectionHeader('Journal de création'),
              const SizedBox(height: 8),
              if (latestNotes.isEmpty)
                _JournalEmpty(theme)
              else
                ...latestNotes.map((n) => _NoteTile(note: n.text, date: n.createdAt)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _openProject(BuildContext context, InventionProject p) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectDetailScreen(projectId: p.id),
      ),
    );
  }
}

class _JournalEmpty extends StatelessWidget {
  final ThemeData theme;
  const _JournalEmpty(this.theme);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(Icons.menu_book_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Ton carnet de bord est vide. Demande à l\'agent : '
                '« note dans mon journal que... »',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  final String note;
  final DateTime date;
  const _NoteTile({required this.note, required this.date});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text(DateFormat('d MMM, HH:mm').format(date),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            child: Column(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(height: 6),
                Text('$value',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                Text(label,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(label,
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              Text(detail,
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}