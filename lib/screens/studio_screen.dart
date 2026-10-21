import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../ai/ai_response.dart';
import '../models/chat_turn.dart';
import '../models/idea_evaluation.dart';
import '../models/invention_project.dart';
import '../models/spark.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/message_cards.dart';
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

  @override
  void initState() {
    super.initState();
    _activeProjectId = widget.seedProjectId;
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _input.clear();
    _scrollBottom();
    final app = context.read<AppState>();
    await app.askAi(text, activeProjectId: _activeProjectId);
    if (mounted) {
      setState(() => _sending = false);
      _scrollBottom();
    }
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final chats = app.data.chats;
    final active = app.data.projectById(_activeProjectId);

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
            child: NotificationListener<ScrollNotification>(
              onNotification: (notif) {
                if (notif.metrics.maxScrollExtent > 0 &&
                    notif.metrics.pixels >=
                        notif.metrics.maxScrollExtent - 8) {
                  _scrollBottom();
                }
                return false;
              },
              child: chats.isEmpty && !_sending
                  ? _WelcomePanel(onPrompt: _send)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      itemCount: chats.length + (_sending ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (_sending && i == chats.length) {
                          return const _TypingBubble();
                        }
                        final turn = chats[i];
                        final projectId = (turn.payload?['projectId'] as String?) ??
                            _activeProjectId;
                        return _MessageBubble(
                          turn: turn,
                          contextProjectId: projectId,
                          onOpenProject: (id) => _openProject(context, id),
                          onAskPlan: (id) => _askPlan(id),
                          onAskEvaluate: (id) => _askEvaluate(id),
                          onInventSpark: (spark) => _inventSpark(spark),
                          onSaveSpark: (spark) => _saveSpark(spark),
                          onCreateFromEvaluation: (evalMap) =>
                              _createFromEvaluation(evalMap),
                          onSetActive: (id) =>
                              setState(() => _activeProjectId = id),
                        );
                      },
                    ),
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
  final void Function(String id) onOpenProject;
  final void Function(String id) onAskPlan;
  final void Function(String id) onAskEvaluate;
  final void Function(SparkContent spark) onInventSpark;
  final void Function(SparkContent spark) onSaveSpark;
  final void Function(Map<String, dynamic> evalMap) onCreateFromEvaluation;
  final void Function(String id) onSetActive;

  const _MessageBubble({
    required this.turn,
    required this.contextProjectId,
    required this.onOpenProject,
    required this.onAskPlan,
    required this.onAskEvaluate,
    required this.onInventSpark,
    required this.onSaveSpark,
    required this.onCreateFromEvaluation,
    required this.onSetActive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = turn.isUser;

    if (isUser) {
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
          child: Text(turn.content, style: theme.textTheme.bodyMedium),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 16),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _content(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context) {
    final widgets = <Widget>[
      Row(
        children: [
          Text(_time(turn.createdAt),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(fontSize: 10)),
          const Spacer(),
          if (turn.payload?['provider'] != null)
            Text('${turn.payload!['provider']}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10)),
        ],
      ),
      const SizedBox(height: 2),
      Text(turn.content, style: Theme.of(context).textTheme.bodyMedium),
    ];

    final payload = turn.payload;
    if (payload == null) return widgets;

    final projectMap = payload['project'] as Map<String, dynamic>?;
    final intent = payload['intent'] as String?;

    if (payload['journalText'] != null && payload['intent'] == 'journal') {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Icon(Icons.menu_book_outlined,
                size: 15, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text('Note ajoutée au journal',
                style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ));
    }

    if (projectMap != null) {
      final project = InventionProject.fromJson(projectMap);
      final id = payload['projectId'] as String?;
      widgets.add(ProjectResponseCard(
        project: project,
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
    }

    final evalMap = payload['evaluation'] as Map<String, dynamic>?;
    if (intent == 'evaluate' && evalMap != null) {
      final evaluation = IdeaEvaluation.fromJson(evalMap);
      widgets.add(EvaluationResponseCard(
        evaluation: evaluation,
        onCreateProject: () => onCreateFromEvaluation(evalMap),
      ));
    }

    final sparkMap = payload['spark'] as Map<String, dynamic>?;
    if (sparkMap != null) {
      final spark = SparkContent.fromJson(sparkMap);
      final sparkId = payload['sparkId'] as String?;
      final alreadySaved = sparkId != null &&
          (context.read<AppState>().data.sparks.any((s) => s.id == sparkId) ||
              sparkIdsMatch(context, spark));
      widgets.add(SparkResponseCard(
        spark: spark,
        onInvent: () => onInventSpark(spark),
        onSave: alreadySaved
            ? null
            : () => onSaveSpark(spark),
      ));
    }

    return widgets;
  }

  bool sparkIdsMatch(BuildContext context, SparkContent spark) {
    return context
        .read<AppState>()
        .data
        .sparks
        .any((s) => s.title == spark.title && s.pitch == spark.pitch);
  }

  String _time(DateTime d) => DateFormat('HH:mm').format(d);
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

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