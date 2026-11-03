import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ai/ai_provider.dart';
import '../ai/image_generator.dart';
import '../models/invention_project.dart';
import '../state/app_state.dart';
import '../state/tab_bus.dart';
import '../widgets/common.dart';

/// Studio visuel : aperçus artistiques d'un projet, générés par un vrai
/// fournisseur d'images. Distinct des plans techniques, qui servent à fabriquer.
class VisualStudioScreen extends StatefulWidget {
  final String projectId;
  const VisualStudioScreen({super.key, required this.projectId});

  @override
  State<VisualStudioScreen> createState() => _VisualStudioScreenState();
}

class _VisualStudioScreenState extends State<VisualStudioScreen> {
  final _change = TextEditingController();
  String _style = VisualStyle.all.first.name;
  String? _selectedId;
  String? _error;

  static const _suggestions = [
    'Fais une version plus simple',
    'Ajoute un socle',
    'Change la couleur principale',
    'Agrandis l\'objet',
  ];

  @override
  void dispose() {
    _change.dispose();
    super.dispose();
  }

  Future<bool> _confirmCost() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Générer une image ?'),
        content: const Text('La génération est facturée par ton fournisseur d\'images (quelques '
            'centimes par image selon le service). Le texte du projet lui est envoyé.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Générer')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _generate(InventionProject p, {VisualVersion? base, String? change}) async {
    if (!await _confirmCost()) return;
    if (!mounted) return;
    setState(() => _error = null);
    try {
      final v = await context.read<AppState>().generateVisual(
            p.id,
            style: base?.style ?? _style,
            modifications: base?.modifications ?? const [],
            newModification: change,
          );
      if (!mounted) return;
      setState(() {
        _selectedId = v.id;
        _change.clear();
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAiError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);
    final p = app.data.projectById(widget.projectId);
    if (p == null) return const Scaffold(body: Center(child: Text('Projet introuvable.')));
    final configured = app.imageGenerator != null;
    final visuals = p.visuals.reversed.toList();
    final selected = visuals.where((v) => v.id == _selectedId).firstOrNull ??
        (visuals.isEmpty ? null : visuals.first);
    final busy = app.aiThinking;

    return Scaffold(
      appBar: AppBar(title: const Text('Studio visuel')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          Text(p.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Aperçu artistique pour visualiser le résultat. Pour fabriquer, utilise les plans '
              'de la conception technique : une image ne donne jamais de cotes.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          if (!configured)
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Génération d\'images non configurée',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text('Ajoute un service d\'images (ex. OpenAI gpt-image-1) dans Réglages → '
                        'Génération d\'images. Aucune image n\'est inventée sans service.'),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: () {
                        Navigator.of(context).popUntil((r) => r.isFirst);
                        context.read<TabBus>().go(4);
                      },
                      child: const Text('Ouvrir les Réglages'),
                    ),
                  ],
                ),
              ),
            ),
          if (selected != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.file(File(selected.filePath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Center(child: Text('Image introuvable.'))),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Style ${selected.style}'
              '${selected.modifications.isEmpty ? '' : ' · ${selected.modifications.join(' · ')}'}',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
          ],
          if (visuals.length > 1)
            SizedBox(
              height: 76,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final v in visuals)
                    GestureDetector(
                      onTap: () => setState(() => _selectedId = v.id),
                      onLongPress: () => app.deleteVisual(p.id, v.id),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              width: 2,
                              color: v.id == selected?.id
                                  ? theme.colorScheme.primary
                                  : Colors.transparent),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(v.filePath),
                              width: 72, height: 72, fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const SizedBox(width: 72)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (visuals.length > 1)
            Text('${visuals.length} versions conservées (appui long pour supprimer).',
                style: theme.textTheme.labelSmall),
          const SizedBox(height: 12),
          const SectionHeader('Nouvel aperçu'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in VisualStyle.all)
                ChoiceChip(
                  label: Text(s.name),
                  selected: _style == s.name,
                  onSelected: (_) => setState(() => _style = s.name),
                ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: !configured || busy ? null : () => _generate(p),
            icon: busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.image_outlined),
            label: Text(busy ? 'Génération en cours…' : 'Générer un aperçu $_style'),
          ),
          if (selected != null) ...[
            const SizedBox(height: 16),
            const SectionHeader('Modifier cet aperçu'),
            const SizedBox(height: 6),
            TextField(
              controller: _change,
              decoration: const InputDecoration(hintText: 'Ex. : allonge le cou du héron'),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in _suggestions)
                  ActionChip(label: Text(s), onPressed: () => setState(() => _change.text = s)),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: !configured || busy
                  ? null
                  : () {
                      final c = _change.text.trim();
                      if (c.isEmpty) return;
                      _generate(p, base: selected, change: c);
                    },
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Appliquer la modification'),
            ),
            const SizedBox(height: 4),
            Text('La modification est aussi notée dans le projet (contraintes envoyées à l\'IA). '
                'L\'aperçu précédent est conservé.',
                style: theme.textTheme.labelSmall),
          ],
          if (_error != null)
            Card(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
              child: Padding(padding: const EdgeInsets.all(12), child: SelectableText(_error!)),
            ),
          if (visuals.isEmpty && configured)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: EmptyState(
                icon: Icons.image_outlined,
                title: 'Aucun aperçu pour l\'instant',
                subtitle: 'Choisis un style et génère un premier aperçu.',
              ),
            ),
        ],
      ),
    );
  }
}
