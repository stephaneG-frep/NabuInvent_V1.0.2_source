import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ai/display_reply.dart';
import '../models/concept.dart';
import '../state/app_state.dart';
import '../state/tab_bus.dart';
import '../widgets/common.dart';
import '../widgets/concept_cards.dart';
import 'photo_materials_screen.dart';
import 'project_detail_screen.dart';
import 'sparks_screen.dart';

/// Atelier d'invention : point d'entrée créatif. Les demandes partent dans le
/// Studio (une seule conversation, une seule mémoire), l'atelier sert à les
/// formuler et à retrouver les concepts.
class AtelierScreen extends StatefulWidget {
  const AtelierScreen({super.key});

  @override
  State<AtelierScreen> createState() => _AtelierScreenState();
}

class _AtelierScreenState extends State<AtelierScreen> {
  final _idea = TextEditingController();
  final _resource = TextEditingController();
  final List<String> _resources = [];

  static const _examples = [
    'Je voudrais fabriquer un canard et un héron avec des boîtes de conserve pour décorer mon jardin.',
    'Je veux fabriquer une lampe de bureau avec du bois de palette.',
    'Je voudrais construire un hôtel à insectes pour le potager.',
  ];

  @override
  void dispose() {
    _idea.dispose();
    _resource.dispose();
    super.dispose();
  }

  void _sendToStudio(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    context.read<TabBus>().go(2);
    context.read<AppState>().askAi(t);
  }

  void _addResource() {
    final r = _resource.text.trim();
    if (r.isEmpty) return;
    setState(() {
      _resources.add(r);
      _resource.clear();
    });
  }

  String _resourcesRequest() {
    final list = _resources.length == 1
        ? _resources.first
        : '${_resources.sublist(0, _resources.length - 1).join(', ')} et ${_resources.last}';
    return 'J\'ai $list. Trouve-moi quelque chose à fabriquer.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.watch<AppState>();
    final conceptCount = _allConcepts(app).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Atelier d\'invention')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          _AtelierBanner(cloud: app.settings.useCloud && app.provider.isConfigured),
          const SizedBox(height: 18),
          const SectionHeader('Une idée à fabriquer'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Décris ce que tu veux réaliser : l\'atelier propose plusieurs concepts '
                      'pour chaque objet.',
                      style: theme.textTheme.bodySmall),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _idea,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                        hintText: 'Ex. : un canard et un héron en boîtes de conserve…'),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final e in _examples)
                        ActionChip(
                          label: Text(e.length > 42 ? '${e.substring(0, 40)}…' : e),
                          onPressed: () => setState(() => _idea.text = e),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      // Une demande à la fois : pas d'appels en double.
                      onPressed: app.aiThinking
                          ? null
                          : () {
                              _sendToStudio(_idea.text);
                              _idea.clear();
                            },
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Proposer des concepts'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const SectionHeader('Avec ce que j\'ai'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Liste tes ressources : l\'inventeur autonome cherche ce qu\'on peut en faire '
                      'et explique ses choix.',
                      style: theme.textTheme.bodySmall),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _resource,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addResource(),
                          decoration:
                              const InputDecoration(hintText: 'Ex. : 4 boîtes de conserve'),
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: _addResource,
                        icon: const Icon(Icons.add),
                        tooltip: 'Ajouter',
                      ),
                    ],
                  ),
                  if (_resources.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i < _resources.length; i++)
                          InputChip(
                            label: Text(_resources[i]),
                            onDeleted: () => setState(() => _resources.removeAt(i)),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _resources.isEmpty || app.aiThinking
                          ? null
                          : () {
                              _sendToStudio(_resourcesRequest());
                              setState(_resources.clear);
                            },
                      icon: const Icon(Icons.lightbulb_outline),
                      label: const Text('Que puis-je fabriquer ?'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const SectionHeader('Explorer'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Qu\'est-ce que je peux fabriquer avec ça ?'),
                  subtitle: const Text('Photographie tes matériaux'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PhotoMaterialsScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.collections_bookmark_outlined),
                  title: const Text('Galerie de concepts'),
                  subtitle: Text(conceptCount == 0
                      ? 'Aucun concept pour l\'instant'
                      : '$conceptCount concept${conceptCount > 1 ? 's' : ''} proposé${conceptCount > 1 ? 's' : ''}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ConceptGalleryScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: const Text('Étincelles'),
                  subtitle: const Text('Combinaisons créatives au hasard'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const SparksScreen())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AtelierBanner extends StatelessWidget {
  final bool cloud;
  const _AtelierBanner({required this.cloud});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.22),
            theme.colorScheme.tertiary.withValues(alpha: 0.12),
          ],
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.handyman, size: 36, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('De l\'idée à l\'objet',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  cloud
                      ? 'Concepts sur mesure, analyse de photo et plans avec ton IA cloud.'
                      : 'Mode local : concepts à partir de modèles types. L\'analyse de photo '
                          'demande le mode cloud.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tous les concepts proposés dans la conversation, du plus récent au plus ancien.
List<InventionConcept> _allConcepts(AppState app) => [
      for (final turn in app.data.chats.reversed)
        if (!turn.isUser) ...DisplayReply.fromTurn(turn).concepts,
    ];

/// Galerie de tous les concepts proposés ; un concept choisi devient un projet.
class ConceptGalleryScreen extends StatelessWidget {
  const ConceptGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final concepts = _allConcepts(app);
    return Scaffold(
      appBar: AppBar(title: const Text('Galerie de concepts')),
      body: concepts.isEmpty
          ? const EmptyState(
              icon: Icons.collections_bookmark_outlined,
              title: 'Pas encore de concepts',
              subtitle: 'Décris une idée dans l\'Atelier : les variantes proposées apparaîtront ici.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
              children: [
                ConceptGalleryCard(
                  concepts: concepts,
                  isChosen: (c) => app.data.projects.any((p) => p.title == c.name),
                  onChoose: (c) {
                    final id = app.adoptConcept(c);
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProjectDetailScreen(projectId: id)));
                  },
                ),
              ],
            ),
    );
  }
}
