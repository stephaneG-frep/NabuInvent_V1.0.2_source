import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../ai/ai_provider.dart';
import '../ai/ai_response.dart';
import '../ai/offline_engine.dart';
import '../ai/openai_provider.dart';
import '../models/app_data.dart';
import '../models/backlog_idea.dart';
import '../models/chat_turn.dart';
import '../models/invention_project.dart';
import '../models/journal_entry.dart';
import '../models/spark.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';

const _uuid = Uuid();

class AppState extends ChangeNotifier {
  final SettingsService settingsService;
  final StorageService storageService;

  AppData data = AppData();
  AppSettings settings = const AppSettings();
  late AiProvider provider;

  AppState({required this.settingsService, required this.storageService}) {
    provider = OfflineEngine();
  }

  String get providerName => provider.name;

  bool get cloudAvailable => settings.useCloud && provider.isConfigured;

  String get aiStatusLabel => settings.useCloud
      ? (provider.isConfigured ? 'Mode cloud (${provider.name})' : 'Mode cloud non configuré')
      : 'Mode local (hors ligne)';

  Future<void> init() async {
    try {
      final s = await settingsService.load();
      final d = await storageService.load();
      settings = s;
      data = d;
      provider = _buildProvider();
      notifyListeners();
    } catch (_) {
      notifyListeners();
    }
  }

  AiProvider _buildProvider() {
    if (settings.useCloud) {
      return OpenAICompatibleProvider(
        baseUrl: settings.aiBaseUrl,
        apiKey: settings.apiKey,
        model: settings.aiModel,
      );
    }
    return OfflineEngine();
  }

  String todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> updateSettings(AppSettings next) async {
    settings = next;
    provider = _buildProvider();
    await settingsService.save(settings);
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      await storageService.save(data);
    } catch (_) {}
  }

  Future<String> exportBackup() async => storageService.exportBackup(data);

  Future<AppData?> importBackup(String path) async {
    final imported = await storageService.importBackup(path);
    if (imported == null) return null;
    data = imported;
    await _persist();
    notifyListeners();
    return imported;
  }

  Future<void> resetAll() async {
    data = AppData();
    await storageService.clearAll();
    notifyListeners();
  }

  int get sparksLeftToday {
    final today = todayKey();
    final used = settings.sparksUsedToday(today);
    return provider.isCloud ? 1000000 : 12 - used;
  }

  Future<int> sparkUsed() async {
    final today = todayKey();
    final used = settings.lastSparkDate == today ? settings.sparkCountToday : 0;
    final next = used + 1;
    await updateSettings(settings.copyWith(
      lastSparkDate: today,
      sparkCountToday: next,
    ));
    return next;
  }

  /// Renvoie null si le fournisseur répond, sinon la raison de l'échec
  /// (message du fournisseur compris) pour l'afficher telle quelle.
  Future<String?> testConnection() async {
    if (!settings.useCloud) return null;
    if (!provider.isConfigured) {
      return 'Renseigne l\'URL de base, la clé API et le modèle.';
    }
    try {
      await provider.respond(userText: 'Réponds en un seul mot : test.');
      return null;
    } on AiHttpException catch (e) {
      return e.toString();
    } on TimeoutException {
      return 'Pas de réponse du fournisseur après 90 s : vérifie ta connexion.';
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<NabuAiResponse> generateSpark({bool challenge = false}) async {
    final text = challenge
        ? 'Lance un défi créatif à contrainte forte pour inventer quelque chose '
            'de surprenant avec très peu de moyens.'
        : 'Donne-moi une étincelle créative aléatoire : combine un domaine, un '
            'mécanisme et un matériau, avec un pitch amusant.';
    final response = await AiService(provider: provider).ask(userText: text);
    if (response.success && response.spark != null) {
      await sparkUsed();
    }
    return response;
  }

  Future<NabuAiResponse> askAi(String userText, {String? activeProjectId}) async {
    final history = _historyForAi();
    final ctxProject = data.projectById(activeProjectId);

    // Le message de l'utilisateur s'affiche tout de suite, sans attendre l'IA.
    _appendTurn(userText, activeProjectId: activeProjectId);
    notifyListeners();

    final response = await AiService(provider: provider).ask(
      userText: userText,
      history: history,
      projectContext:
          ctxProject == null ? null : jsonEncode(ctxProject.toJson()),
    );

    _applyResponse(response, userText: userText, activeProjectId: activeProjectId);
    await _persist();
    notifyListeners();
    return response;
  }

  /// Les 10 derniers tours utiles : les échanges en erreur (et la question qui
  /// les a provoqués) ne sont pas renvoyés au modèle comme contexte.
  List<AiTurn> _historyForAi() {
    final chats = data.chats;
    final turns = <AiTurn>[];
    for (var i = 0; i < chats.length; i++) {
      final t = chats[i];
      if (_isFailedTurn(t)) continue;
      if (t.isUser && i + 1 < chats.length && _isFailedTurn(chats[i + 1])) {
        continue;
      }
      turns.add(AiTurn(t.role, t.content));
    }
    return turns.length > 10 ? turns.sublist(turns.length - 10) : turns;
  }

  bool _isFailedTurn(ChatTurn t) => !t.isUser && t.payload?['success'] == false;

  void _appendTurn(String text, {String? activeProjectId}) {
    data = data.copyWith(
      chats: [
        ...data.chats,
        ChatTurn(
          role: 'user',
          content: text,
          payload: activeProjectId == null ? null : {'projectId': activeProjectId},
        ),
      ],
    );
  }

  void _applyResponse(
    NabuAiResponse r, {
    required String userText,
    String? activeProjectId,
  }) {
    final project = r.project;
    final active = data.projectById(activeProjectId);
    String? projectId;

    switch (r.intent) {
      case AiIntent.invent when project != null:
        // Une invention est toujours un nouveau projet : on ne réutilise jamais
        // un id existant, sinon le projet en cours serait écrasé.
        project.id = _uuid.v4();
        data = data.copyWith(projects: [...data.projects, project]);
        projectId = project.id;
      case AiIntent.refine when project != null:
        final target = data.projectById(project.id) ?? active;
        if (target != null) {
          _mergeInto(target, project, plan: r.plan);
          projectId = target.id;
        } else {
          project.id = _uuid.v4();
          data = data.copyWith(projects: [...data.projects, project]);
          projectId = project.id;
        }
      case AiIntent.plan:
        final plan = r.plan ?? project?.plan;
        if (plan == null || plan.steps.isEmpty) break;
        final target = data.projectById(project?.id) ?? active;
        if (target != null) {
          _mergeInto(target, project, plan: plan);
          projectId = target.id;
        } else {
          final created = project ?? InventionProject(id: '', title: _titleFrom(userText));
          created
            ..id = _uuid.v4()
            ..plan = plan
            ..status = ProjectStatus.plan;
          data = data.copyWith(projects: [...data.projects, created]);
          projectId = created.id;
        }
      default:
        break;
    }

    final turnPayload = r.toJson();
    if (projectId != null) turnPayload['projectId'] = projectId;
    if (r.intent == AiIntent.spark && r.spark != null) {
      turnPayload['sparkId'] = _uuid.v4();
    }

    final journalText = r.journalText;
    if (journalText != null && journalText.trim().isNotEmpty) {
      data = data.copyWith(journal: [
        ...data.journal,
        JournalEntry(
          id: _uuid.v4(),
          text: journalText,
          projectId: projectId ?? activeProjectId,
        ),
      ]);
    }

    data = data.copyWith(
      chats: [
        ...data.chats,
        ChatTurn(
          role: 'assistant',
          content: r.message,
          payload: turnPayload,
        ),
      ],
    );
  }

  /// Met à jour un projet existant sans perdre ce que l'IA n'a pas renvoyé :
  /// seuls les champs non vides remplacent les valeurs actuelles. Statut,
  /// étoile, date de création et progression sont conservés.
  void _mergeInto(InventionProject target, InventionProject? update, {ProjectPlan? plan}) {
    if (update != null) {
      String pick(String next, String current) =>
          next.trim().isNotEmpty ? next : current;
      List<String> pickList(List<String> next, List<String> current) =>
          next.isNotEmpty ? List.of(next) : current;
      target
        ..title = pick(update.title, target.title)
        ..problem = pick(update.problem, target.problem)
        ..subtitle = pick(update.subtitle, target.subtitle)
        ..concept = pick(update.concept, target.concept)
        ..mechanism = pick(update.mechanism, target.mechanism)
        ..materials = pickList(update.materials, target.materials)
        ..tools = pickList(update.tools, target.tools)
        ..budget = pick(update.budget, target.budget)
        ..timeEstimate = pick(update.timeEstimate, target.timeEstimate)
        ..category = pick(update.category, target.category)
        ..tags = pickList(update.tags, target.tags);
    }
    if (plan != null && plan.steps.isNotEmpty) {
      target.plan = plan;
      if (target.status == ProjectStatus.idea) target.status = ProjectStatus.plan;
    }
    target.touch();
    _replaceProject(target);
  }

  String _titleFrom(String userText) {
    final t = userText.trim();
    if (t.isEmpty) return 'Nouveau projet';
    return t.length > 60 ? '${t.substring(0, 57)}…' : t;
  }

  void _replaceProject(InventionProject project) {
    data = data.copyWith(
      projects: [for (final p in data.projects) p.id == project.id ? project : p],
    );
  }

  void createProject(InventionProject project) {
    if (project.id.isEmpty) project.id = _uuid.v4();
    data = data.copyWith(projects: [...data.projects, project]);
    _persist();
    notifyListeners();
  }

  void updateProject(InventionProject project) {
    _replaceProject(project);
    _persist();
    notifyListeners();
  }

  void deleteProject(String id) {
    data = data.copyWith(projects: [for (final p in data.projects) if (p.id != id) p]);
    _persist();
    notifyListeners();
  }

  void setProjectStatus(String id, ProjectStatus status) {
    final p = data.projectById(id);
    if (p == null) return;
    p
      ..status = status
      ..touch();
    _replaceProject(p);
    _persist();
    notifyListeners();
  }

  void toggleStar(String id) {
    final p = data.projectById(id);
    if (p == null) return;
    p.starred = !p.starred;
    _replaceProject(p);
    _persist();
    notifyListeners();
  }

  void toggleStepDone(String projectId, String stepId) {
    final p = data.projectById(projectId);
    if (p == null) return;
    final steps = p.plan.steps;
    for (final s in steps) {
      if (s.id == stepId) {
        s.done = !s.done;
      }
    }
    if (p.plan.steps.isNotEmpty &&
        p.plan.completedCount == p.plan.steps.length &&
        p.status != ProjectStatus.built) {
      p.status = ProjectStatus.built;
    }
    p.touch();
    _replaceProject(p);
    _persist();
    notifyListeners();
  }

  void updatePlan(String projectId, ProjectPlan plan) {
    final p = data.projectById(projectId);
    if (p == null) return;
    p.plan = plan;
    p.status = p.status == ProjectStatus.idea ? ProjectStatus.plan : p.status;
    p.touch();
    _replaceProject(p);
    _persist();
    notifyListeners();
  }

  void addJournalEntry(String text, {String? projectId}) {
    data = data.copyWith(journal: [
      ...data.journal,
      JournalEntry(id: _uuid.v4(), text: text, projectId: projectId),
    ]);
    _persist();
    notifyListeners();
  }

  void deleteJournalEntry(String id) {
    data = data.copyWith(
        journal: [for (final j in data.journal) if (j.id != id) j]);
    _persist();
    notifyListeners();
  }

  void addBacklogIdea(String title, {String note = '', List<String> tags = const []}) {
    data = data.copyWith(backlog: [
      ...data.backlog,
      BacklogIdea(id: _uuid.v4(), title: title, note: note, tags: tags),
    ]);
    _persist();
    notifyListeners();
  }

  void setBacklogArchived(String id, bool archived) {
    data = data.copyWith(backlog: [
      for (final b in data.backlog)
        b.id == id
            ? BacklogIdea(
                id: b.id,
                title: b.title,
                note: b.note,
                tags: b.tags,
                createdAt: b.createdAt,
                convertedProjectId: b.convertedProjectId,
                archived: archived,
              )
            : b,
    ]);
    _persist();
    notifyListeners();
  }

  void deleteBacklogIdea(String id) {
    data = data.copyWith(
      backlog: [for (final b in data.backlog) if (b.id != id) b],
    );
    _persist();
    notifyListeners();
  }

  String promoteBacklogToProject(String id) {
    final idea = data.backlog.where((b) => b.id == id).firstOrNull;
    if (idea == null) return '';
    final project = InventionProject(
      id: _uuid.v4(),
      title: idea.title,
      problem: idea.note,
      subtitle: idea.note,
      category: idea.tags.isNotEmpty ? idea.tags.first : 'Idée',
      tags: List.of(idea.tags),
    );
    data = data.copyWith(
      projects: [...data.projects, project],
      backlog: [
        for (final b in data.backlog)
          b.id == id
              ? BacklogIdea(
                  id: b.id,
                  title: b.title,
                  note: b.note,
                  tags: b.tags,
                  createdAt: b.createdAt,
                  convertedProjectId: project.id,
                )
              : b,
      ],
    );
    _persist();
    notifyListeners();
    return project.id;
  }

  void saveSpark(Spark spark) {
    if (data.sparks.any((s) => s.id == spark.id)) return;
    data = data.copyWith(sparks: [...data.sparks, spark]);
    _persist();
    notifyListeners();
  }

  void deleteSpark(String id) {
    data = data.copyWith(sparks: [for (final s in data.sparks) if (s.id != id) s]);
    _persist();
    notifyListeners();
  }

  List<JournalEntry> journalFor(String? projectId) {
    final list = projectId == null
        ? data.journal
        : data.journal.where((j) => j.projectId == projectId).toList();
    return list.reversed.toList();
  }
}