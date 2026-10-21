import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/common.dart';
import 'project_detail_screen.dart';

class JournalScreen extends StatefulWidget {
  final String? projectId;
  const JournalScreen({super.key, this.projectId});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  void _addNote() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nouvelle note de création'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Tes pensées, tes progrès…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<AppState>().addJournalEntry(
                      controller.text.trim(),
                      projectId: widget.projectId,
                    );
              }
              Navigator.of(context).pop();
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final project = app.data.projectById(widget.projectId);
    final entries = app.journalFor(widget.projectId);

    return Scaffold(
      appBar: AppBar(
        title: Text(project == null ? 'Journal de création' : 'Journal — ${project.title}'),
      ),
      body: entries.isEmpty
          ? EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'Journal vide',
              subtitle:
                  'Note tes idées, tes essais, tes réussites et tes échecs : c\'est '
                  'la matière première de l\'inventeur.',
              action: FilledButton.icon(
                onPressed: _addNote,
                icon: const Icon(Icons.add),
                label: const Text('Écrire une note'),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final e = entries[i];
                final related = project == null ? app.data.projectById(e.projectId) : null;
                return Dismissible(
                  key: ValueKey(e.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  ),
                  onDismissed: (_) {
                    context.read<AppState>().deleteJournalEntry(e.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Note supprimée.')),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.edit_note,
                                  size: 17,
                                  color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('EEEE d MMM yyyy, HH:mm').format(e.createdAt),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              const Spacer(),
                              if (related != null)
                                InkWell(
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ProjectDetailScreen(projectId: related.id),
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(related.title,
                                        style: Theme.of(context).textTheme.labelSmall),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(e.text, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNote,
        icon: const Icon(Icons.edit),
        label: const Text('Écrire'),
      ),
    );
  }
}