import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/invention_project.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Historique des versions d'un projet : chaque modification par l'IA ou
/// chaque retour en arrière conserve l'état précédent.
class VersionsScreen extends StatelessWidget {
  final String projectId;
  const VersionsScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.data.projectById(projectId);
    if (p == null) return const Scaffold(body: Center(child: Text('Projet introuvable.')));
    final versions = p.versions.reversed.toList();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Versions du projet')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          if (p.designNotes.isNotEmpty) ...[
            const SectionHeader('Contraintes mémorisées'),
            Card(
              child: Column(
                children: [
                  for (final n in p.designNotes)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.push_pin_outlined, size: 18),
                      title: Text(n),
                    ),
                ],
              ),
            ),
            Text('Elles accompagnent le projet dans chaque demande à l\'IA.',
                style: theme.textTheme.labelSmall),
            const SizedBox(height: 16),
          ],
          const SectionHeader('Versions antérieures'),
          if (versions.isEmpty)
            const EmptyState(
              icon: Icons.history,
              title: 'Aucune version antérieure',
              subtitle: 'Une copie est enregistrée avant chaque modification du projet par l\'IA.',
            )
          else
            for (final v in versions) _VersionTile(project: p, version: v),
        ],
      ),
    );
  }
}

class _VersionTile extends StatelessWidget {
  final InventionProject project;
  final ProjectVersion version;
  const _VersionTile({required this.project, required this.version});

  @override
  Widget build(BuildContext context) {
    final snap = InventionProject.fromJson(version.snapshot);
    final details = [
      '${snap.materials.length} matériau(x)',
      '${snap.plan.steps.length} étape(s)',
      if (snap.tech != null) '${snap.tech!.parts.length} pièce(s) cotée(s)',
    ].join(' · ');
    return Card(
      child: ListTile(
        title: Text(version.reason),
        subtitle: Text('${DateFormat('dd/MM/yyyy HH:mm').format(version.createdAt)}\n'
            '« ${snap.title} » — $details'),
        isThreeLine: true,
        trailing: TextButton(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Revenir à cette version ?'),
                content: const Text('L\'état actuel du projet sera lui-même conservé dans les versions.'),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
                  FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Restaurer')),
                ],
              ),
            );
            if (ok == true && context.mounted) {
              context.read<AppState>().restoreVersion(project.id, version.id);
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Version restaurée.')));
            }
          },
          child: const Text('Restaurer'),
        ),
      ),
    );
  }
}
