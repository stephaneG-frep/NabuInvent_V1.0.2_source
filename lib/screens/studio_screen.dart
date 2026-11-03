import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../ai/ai_response.dart';
import '../ai/display_reply.dart';
import '../ai/redact.dart';
import '../models/chat_turn.dart';
import '../models/concept.dart';
import '../models/invention_project.dart';
import '../models/spark.dart';
import '../state/app_state.dart';
import '../tech/safety_checker.dart';
import '../widgets/common.dart';
import '../widgets/concept_cards.dart';
import '../widgets/invention_sections.dart';
import '../widgets/message_cards.dart';
import '../widgets/rich_message.dart';
import 'project_detail_screen.dart';

const _uuid = Uuid();

class StudioScreen extends StatefulWidget {
  final String? seedProjectId;
  const StudioScreen({super.key, this.seedProjectId});

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  String? _activeProjectId;
  bool _sending = false;

  /// L'utilisateur est-il en bas de la conversation ? Seul cas où l'arrivée
  /// d'un message fait défiler automatiquement : on ne ramène jamais en bas
  /// quelqu'un qui relit un ancien message.
  bool _atBottom = true;

  /// Un message vient d'être envoyé par l'utilisateur : on le montre.
  bool _followNext = false;
  int _lastItemCount = 0;
  double _lastKeyboardInset = 0;

  /// Distance au bas sous laquelle on considère l'utilisateur « en bas ».
  static const _bottomTolerance = 80.0;

  @override
  void initState() {
    super.initState();
    _activeProjectId = widget.seedProjectId;
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final atBottom = _isNearBottom();
    if (atBottom != _atBottom) setState(() => _atBottom = atBottom);
  }

  bool _isNearBottom() {
    if (!_scroll.hasClients) return true;
    final p = _scroll.position;
    return p.pixels >= p.maxScrollExtent - _bottomTolerance;
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _sending) return;
    _followNext = true;
    setState(() => _sending = true);
    _input.clear();
    final app = context.read<AppState>();
    await app.askAi(text, activeProjectId: _activeProjectId);
    _followNext = false;
    // La réponse remplace l'indicateur de saisie : son début reste visible
    // là où l'utilisateur regardait, sans saut jusqu'à sa fin.
    if (mounted) setState(() => _sending = false);
  }

  /// Va au dernier message. Les éléments de la liste sont construits à la
  /// demande : la hauteur totale n'est connue qu'en approchant du bas, d'où
  /// le saut final pour atteindre la vraie fin.
  void _scrollToEnd({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scroll.hasClients) return;
      if (animate) {
        await _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
      for (var i = 0; i < 3 && mounted && _scroll.hasClients; i++) {
        final max = _scroll.position.maxScrollExtent;
        if (_scroll.position.pixels >= max - 1) break;
        _scroll.jumpTo(max);
        await WidgetsBinding.instance.endOfFrame;
      }
    });
  }

  /// Défilement automatique, décidé une fois par construction de l'écran.
  void _autoScroll(int itemCount, double keyboardInset) {
    if (itemCount > _lastItemCount && (_atBottom || _followNext)) {
      _scrollToEnd(animate: _lastItemCount > 0);
    }
    if (keyboardInset > _lastKeyboardInset && _atBottom) {
      _scrollToEnd(animate: false);
    }
    _lastItemCount = itemCount;
    _lastKeyboardInset = keyboardInset;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final chats = app.data.chats;
    final active = app.data.projectById(_activeProjectId);
    final thinking = _sending || app.aiThinking;
    final itemCount = chats.length + (thinking ? 1 : 0);
    _autoScroll(itemCount, MediaQuery.viewInsetsOf(context).bottom);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Studio d\'invention'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: _providerBadge(app)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chats.isEmpty && !thinking
                ? _WelcomePanel(onPrompt: _send)
                : Stack(
                    children: [
                      // Un seul défilement vertical pour toute la conversation :
                      // les bulles n'ont jamais de défilement interne.
                      ListView.builder(
                        key: const Key('studio-conversation'),
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        itemCount: itemCount,
                        itemBuilder: (context, i) {
                          if (thinking && i == chats.length) {
                            return _TypingBubble(onCancel: app.cancelAi);
                          }
                          final turn = chats[i];
                          final projectId = (turn.payload?['projectId'] as String?) ??
                              _activeProjectId;
                          return _MessageBubble(
                            turn: turn,
                            contextProjectId: projectId,
                            technicalMode: app.settings.technicalMode,
                            onOpenProject: (id) => _openProject(context, id),
                            onAskPlan: (id) => _askPlan(id),
                            onAskEvaluate: (id) => _askEvaluate(id),
                            onInventSpark: (spark) => _inventSpark(spark),
                            onSaveSpark: (spark) => _saveSpark(spark),
                            onCreateFromEvaluation: (evalMap) =>
                                _createFromEvaluation(evalMap),
                            onSetActive: (id) =>
                                setState(() => _activeProjectId = id),
                            onChooseConcept: _chooseConcept,
                          );
                        },
                      ),
                      if (!_atBottom)
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: FilledButton.tonalIcon(
                            key: const Key('studio-latest'),
                            onPressed: () => _scrollToEnd(),
                            icon: const Icon(Icons.arrow_downward, size: 18),
                            label: const Text('Dernier message'),
                          ),
                        ),
                    ],
                  ),
          ),
          if (active != null)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: _ActiveProjectChip(
                title: active.title,
                onClear: () => setState(() => _activeProjectId = null),
              ),
            ),
          _QuickPrompts(onPrompt: _send),
          _InputBar(
            controller: _input,
            sending: _sending,
            onSend: () => _send(_input.text),
          ),
        ],
      ),
    );
  }

  Widget _providerBadge(AppState app) {
    final isCloud = app.settings.useCloud;
    final ready = isCloud && app.provider.isConfigured;
    final color = !isCloud
        ? Colors.green
        : ready
            ? Colors.green
            : Colors.orange;
    final label = !isCloud
        ? 'Mode local'
        : ready
            ? 'Cloud prêt'
            : 'Cloud à configurer';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  /// Concept choisi dans une galerie. En mode cloud, le modèle développe le
  /// concept en fiche complète ; en local, le projet est créé directement à
  /// partir des données du concept.
  void _chooseConcept(InventionConcept concept) {
    final app = context.read<AppState>();
    if (app.settings.useCloud && app.provider.isConfigured) {
      setState(() => _activeProjectId = null);
      _send('Je choisis le concept « ${concept.name} »'
          '${concept.subject.isEmpty ? '' : ' (${concept.subject})'}. '
          'Développe-le en fiche projet complète.');
      return;
    }
    final id = app.adoptConcept(concept);
    setState(() => _activeProjectId = id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Projet « ${concept.name} » créé. Demande « élabore le plan » pour la suite.'),
      action: SnackBarAction(label: 'Voir', onPressed: () => _openProject(context, id)),
    ));
  }

  void _openProject(BuildContext context, String id) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectDetailScreen(projectId: id),
      ),
    );
  }

  void _askPlan(String id) {
    setState(() => _activeProjectId = id);
    _send('Élabore le plan de construction détaillé de ce projet, étape par étape.');
  }

  void _askEvaluate(String id) {
    setState(() => _activeProjectId = id);
    _send('Évalue cette idée de projet.');
  }

  void _inventSpark(SparkContent spark) {
    setState(() => _activeProjectId = null);
    _send('Conçois une invention à partir de cette étincelle : ${spark.title} — ${spark.pitch}');
  }

  void _saveSpark(SparkContent spark) {
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
      const SnackBar(content: Text('Étincelle sauvegardée dans ton coffre.')),
    );
  }

  void _createFromEvaluation(Map<String, dynamic> evalMap) {
    final idea = evalMap['idea'] as String? ?? '';
    final title = idea.length > 60 ? '${idea.substring(0, 57)}…' : idea;
    final app = context.read<AppState>();
    final project = InventionProject(
      id: _uuid.v4(),
      title: title,
      problem: idea,
      subtitle: idea,
      score: app.data.projects.length,
    );
    app.createProject(project);
    _openProject(context, project.id);
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatTurn turn;
  final String? contextProjectId;
  final bool technicalMode;
  final void Function(String id) onOpenProject;
  final void Function(String id) onAskPlan;
  final void Function(String id) onAskEvaluate;
  final void Function(SparkContent spark) onInventSpark;
  final void Function(SparkContent spark) onSaveSpark;
  final void Function(Map<String, dynamic> evalMap) onCreateFromEvaluation;
  final void Function(String id) onSetActive;
  final void Function(InventionConcept concept) onChooseConcept;

  const _MessageBubble({
    required this.turn,
    required this.contextProjectId,
    required this.technicalMode,
    required this.onOpenProject,
    required this.onAskPlan,
    required this.onAskEvaluate,
    required this.onInventSpark,
    required this.onSaveSpark,
    required this.onCreateFromEvaluation,
    required this.onSetActive,
    required this.onChooseConcept,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (turn.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 60),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: SelectionArea(
            child: Text(turn.content, style: theme.textTheme.bodyMedium),
          ),
        ),
      );
    }

    final reply = DisplayReply.fromTurn(turn);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lightbulb, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                // Sélection tactile par appui long ; le glissement vertical
                // reste au défilement de la conversation.
                child: SelectionArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _content(context, reply),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, DisplayReply reply) {
    final theme = Theme.of(context);
    final widgets = <Widget>[
      Row(
        children: [
          Text(_time(turn.createdAt),
              style: theme.textTheme.labelSmall?.copyWith(fontSize: 10)),
          const Spacer(),
          if (reply.provider != null)
            Flexible(
              child: Text(reply.provider!,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(fontSize: 10)),
            ),
        ],
      ),
      const SizedBox(height: 4),
      RichMessage(reply.message),
    ];

    if (reply.journalText != null && reply.intent == 'journal') {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Icon(Icons.menu_book_outlined, size: 15, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text('Note ajoutée au journal', style: theme.textTheme.labelMedium),
          ],
        ),
      ));
    }

    final project = reply.project;
    if (project != null) {
      final id = reply.projectId;
      widgets.add(InventionResultCard(
        project: project,
        plan: reply.intent == 'plan' ? reply.plan : null,
        extraWarnings: [for (final f in SafetyChecker.checkProject(project)) f.text],
        partial: reply.partial,
        onOpen: id == null ? null : () => onOpenProject(id),
        onPlan: id == null ? null : () => onAskPlan(id),
        onEvaluate: id == null ? null : () => onAskEvaluate(id),
      ));
      if (id != null && id != contextProjectId) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 6),
          child: TextButton.icon(
            onPressed: () => onSetActive(id),
            icon: const Icon(Icons.push_pin, size: 15),
            label: const Text('Continuer sur ce projet'),
          ),
        ));
      }
    } else if (reply.plan != null && reply.plan!.steps.isNotEmpty) {
      // Plan seul (sans fiche projet) : étapes et précautions.
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstructionSteps(reply.plan!.steps, initiallyExpanded: true),
            SafetyWarnings([for (final s in reply.plan!.steps) s.safety]),
          ],
        ),
      ));
    }

    final evaluation = reply.evaluation;
    if (reply.intent == 'evaluate' && evaluation != null) {
      widgets.add(EvaluationResponseCard(
        evaluation: evaluation,
        onCreateProject: () => onCreateFromEvaluation(reply.evaluationJson ?? evaluation.toJson()),
      ));
    }

    final spark = reply.spark;
    if (spark != null) {
      final sparks = context.read<AppState>().data.sparks;
      final alreadySaved = sparks.any((s) => s.id == reply.sparkId) ||
          sparks.any((s) => s.title == spark.title && s.pitch == spark.pitch);
      widgets.add(SparkResponseCard(
        spark: spark,
        onInvent: () => onInventSpark(spark),
        onSave: alreadySaved ? null : () => onSaveSpark(spark),
      ));
    }

    if (reply.concepts.isNotEmpty) {
      final projects = context.read<AppState>().data.projects;
      widgets.add(ConceptGalleryCard(
        concepts: reply.concepts,
        resources: reply.resources,
        onChoose: onChooseConcept,
        isChosen: (c) => projects.any((p) => p.title == c.name),
      ));
    }

    if (reply.partial && project == null) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text('Réponse incomplète ou mal formée, récupérée au mieux.',
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error)),
      ));
    }

    if (technicalMode && reply.raw != null) {
      widgets.add(_RawJsonPanel(raw: reply.raw!));
    }

    return widgets;
  }

  String _time(DateTime d) => DateFormat('HH:mm').format(d);
}

/// Mode technique : texte d'origine renvoyé par le modèle (secrets masqués).
class _RawJsonPanel extends StatelessWidget {
  final String raw;
  const _RawJsonPanel({required this.raw});

  /// Au-delà, l'affichage est tronqué (le texte complet reste copiable).
  static const _maxShown = 20000;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = redactSecrets(raw);
    final shown = text.length > _maxShown
        ? '${text.substring(0, _maxShown)}\n… (${text.length - _maxShown} caractères non affichés)'
        : text;
    return CollapsibleSection(
      title: 'JSON d\'origine',
      icon: Icons.data_object,
      badge: '${text.length} car.',
      initiallyExpanded: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(shown,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          ),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('JSON copié.')));
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copier'),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  final VoidCallback onCancel;
  const _TypingBubble({required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            const SizedBox(
              width: 60,
              height: 12,
              child: LinearProgressIndicator(),
            ),
            const SizedBox(width: 6),
            TextButton(onPressed: onCancel, child: const Text('Annuler')),
          ],
        ),
      ),
    );
  }
}

class _ActiveProjectChip extends StatelessWidget {
  final String title;
  final VoidCallback onClear;
  const _ActiveProjectChip({required this.title, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.push_pin, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(title, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 16),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  final void Function(String) onPrompt;
  const _WelcomePanel({required this.onPrompt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ideas = [
      'Invente un objet pour ranger les câbles du bureau.',
      'Un arroseur automatique pour mes plantes pendant les vacances.',
      'Évalue mon idée : une serre de balcon en palette.',
      'Donne-moi une étincelle créative pour ce week-end.',
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 30, 14, 14),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.16),
                theme.colorScheme.tertiaryContainer.withValues(alpha: 0.16),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Icon(Icons.psychology, size: 40, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text('Bienvenue dans le Studio d\'invention',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Décris un problème, demande une invention complète, un plan '
                'de construction, une évaluation d\'idée ou une étincelle créative.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader('Que veux-tu faire ?'),
        const SizedBox(height: 8),
        for (final idea in ideas)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onPrompt(idea),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.play_arrow, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(idea, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickPrompts extends StatelessWidget {
  final void Function(String) onPrompt;
  const _QuickPrompts({required this.onPrompt});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Invente', 'Invente-moi un objet pour :'),
      ('Étincelle', 'Donne-moi une étincelle créative.'),
      ('Évaluer', 'Évalue cette idée :'),
      ('Carnet', 'Écris dans mon journal :'),
    ];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        children: [
          for (final (label, prompt) in items)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ActionChip(
                avatar: const Icon(Icons.bolt, size: 16),
                label: Text(label),
                onPressed: () => onPrompt(prompt),
              ),
            ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !sending,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Dis-moi quoi inventer…',
                suffixIcon: IconButton(
                  onPressed: onSend,
                  icon: Icon(
                    sending ? Icons.hourglass_top : Icons.send_rounded,
                    color: sending
                        ? null
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}