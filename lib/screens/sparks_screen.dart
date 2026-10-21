import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../ai/ai_response.dart';
import '../models/spark.dart';
import '../state/app_state.dart';
import '../state/tab_bus.dart';
import '../widgets/common.dart';

const _uuid = Uuid();

class SparksScreen extends StatefulWidget {
  const SparksScreen({super.key});

  @override
  State<SparksScreen> createState() => _SparksScreenState();
}

class _SparksScreenState extends State<SparksScreen> {
  SparkContent? _current;
  bool _loading = false;

  Future<void> _generate({bool challenge = false}) async {
    final app = context.read<AppState>();
    if (!app.provider.isCloud && app.sparksLeftToday <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Limite du jour atteinte en mode local (12 étincelles). '
                'Reviens demain ou passe en mode cloud.')));
      }
      return;
    }
    setState(() => _loading = true);
    final response = await app.generateSpark(challenge: challenge);
    if (mounted) {
      setState(() {
        _current = response.spark;
        _loading = false;
      });
    }
  }

  void _invent(SparkContent spark) {
    context.read<TabBus>().go(2);
    context.read<AppState>().askAi(
        'Conçois une invention à partir de cette étincelle : ${spark.title} — ${spark.pitch}');
  }

  void _save(SparkContent spark) {
    context.read<AppState>().saveSpark(
          Spark(
            id: _uuid.v4(),
            title: spark.title,
            domain: spark.domain,
            mechanism: spark.mechanism,
            material: spark.material,
            pitch: spark.pitch,
            challenge: spark.challenge,
            saved: true,
          ),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Étincelle ajoutée à ton coffre.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final saved = app.data.sparks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Étincelles créatives'),
        actions: [
          if (!app.provider.isCloud)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${app.sparksLeftToday} restantes',
                      style: const TextStyle(
                          color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
        children: [
          Text(
            'Des combos inattendus pour téléporter ton cerveau dans des zones '
            'inconnues. Génère, invente, recommence.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _loading ? null : () => _generate(),
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome),
                label: Text(_loading ? 'Étincelle en cours…' : 'Nouvelle étincelle'),
              ),
              OutlinedButton.icon(
                onPressed: _loading ? null : () => _generate(challenge: true),
                icon: const Icon(Icons.local_fire_department),
                label: const Text('Défi créatif'),
              ),
            ],
          ),
          if (_current != null) ...[
            const SizedBox(height: 14),
            Card(
              color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.35),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome,
                            color: _current!.challenge
                                ? Colors.deepOrange
                                : Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_current!.title.isNotEmpty
                              ? _current!.title
                              : 'Étincelle',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    if (_current!.pitch.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_current!.pitch, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () => _invent(_current!),
                          icon: const Icon(Icons.psychology, size: 18),
                          label: const Text('Inventer ça'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _save(_current!),
                          icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                          label: const Text('Sauvegarder'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const SectionHeader('Coffre à étincelles'),
          const SizedBox(height: 6),
          if (saved.isEmpty)
            const EmptyState(
              icon: Icons.auto_awesome_outlined,
              title: 'Coffre vide',
              subtitle: 'Les étincelles que tu sauvegardes s\'affichent ici.',
            )
          else
            for (final spark in saved)
              _SavedSparkTile(
                spark: spark,
                onInvent: () => _invent(SparkContent(
                  title: spark.title,
                  domain: spark.domain,
                  mechanism: spark.mechanism,
                  material: spark.material,
                  pitch: spark.pitch,
                  challenge: spark.challenge,
                )),
                onDelete: () => app.deleteSpark(spark.id),
              ),
        ],
      ),
    );
  }
}

class _SavedSparkTile extends StatelessWidget {
  final Spark spark;
  final VoidCallback onInvent;
  final VoidCallback onDelete;
  const _SavedSparkTile({
    required this.spark,
    required this.onInvent,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          spark.challenge ? Icons.local_fire_department : Icons.auto_awesome,
          size: 18,
          color: spark.challenge ? Colors.deepOrange : theme.colorScheme.primary,
        ),
      ),
      title: Text(spark.title.isEmpty ? 'Étincelle' : spark.title,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      subtitle: spark.domain.isEmpty
          ? null
          : Text('${spark.domain} · ${spark.material}'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        if (spark.pitch.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(spark.pitch, style: theme.textTheme.bodySmall),
            ),
          ),
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: onInvent,
              icon: const Icon(Icons.psychology, size: 17),
              label: const Text('Inventer'),
            ),
            const Spacer(),
            IconButton(
              onPressed: onDelete,
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ],
    );
  }
}