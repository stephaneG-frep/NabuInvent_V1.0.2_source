import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../ai/ai_provider.dart';
import '../ai/ai_response.dart';
import '../ai/image_generator.dart';
import '../ai/offline_engine.dart';
import '../ai/openai_provider.dart';
import '../models/app_data.dart';
import '../models/backlog_idea.dart';
import '../models/chat_turn.dart';
import '../models/concept.dart';
import '../models/invention_project.dart';
import '../models/journal_entry.dart';
import '../models/spark.dart';
import '../models/tech_sheet.dart';
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

  int _pendingAi = 0;

  /// Une demande à l'IA est en cours (quel que soit l'écran qui l'a lancée).
  bool get aiThinking => _pendingAi > 0;

  Future<NabuAiResponse> askAi(String userText, {String? activeProjectId}) async {
    final history = _historyForAi();
    final ctxProject = data.projectById(activeProjectId);

    // Le message de l'utilisateur s'affiche tout de suite, sans attendre l'IA.
    _appendTurn(userText, activeProjectId: activeProjectId);
    if (ctxProject != null) _rememberConstraint(ctxProject, userText);

    // Mode local : « le deuxième me plaît » désigne un concept déjà proposé.
    if (!provider.isCloud) {
      final local = _resolveConceptChoice(userText);
      if (local != null) {
        await _persist();
        notifyListeners();
        return local;
      }
    }

    _pendingAi++;
    notifyListeners();

    final NabuAiResponse response;
    try {
      response = await AiService(provider: provider).ask(
        userText: userText,
        history: history,
        projectContext:
            ctxProject == null ? null : jsonEncode(ctxProject.toSnapshotJson()),
      );
    } finally {
      _pendingAi--;
    }

    _applyResponse(response, userText: userText, activeProjectId: activeProjectId);
    await _persist();
    notifyListeners();
    return response;
  }

  /// Fournisseur capable d'analyser une photo, ou null (mode local, cloud non
  /// configuré) : la fonction est alors indiquée comme indisponible.
  VisionProvider? get vision {
    final p = provider;
    return settings.useCloud && p.isConfigured && p is VisionProvider
        ? p as VisionProvider
        : null;
  }

  /// Le fournisseur actuel a-t-il déjà reçu l'accord pour les photos ?
  bool get photoConsentGiven =>
      settings.photoConsentUrl.isNotEmpty &&
      settings.photoConsentUrl == settings.aiBaseUrl.trim();

  Future<void> rememberPhotoConsent() =>
      updateSettings(settings.copyWith(photoConsentUrl: settings.aiBaseUrl.trim()));

  /// Service de génération d'images configuré, ou null (fonction indiquée
  /// comme non configurée, jamais simulée).
  ImageGenerator? get imageGenerator {
    final g = OpenAIImageGenerator(
      baseUrl: settings.imageBaseUrl,
      apiKey: settings.imageApiKey,
      model: settings.imageModel,
    );
    return g.isConfigured ? g : null;
  }

  /// Génère un aperçu artistique. Une modification (« allonge le cou ») est
  /// aussi notée dans le projet : le concept évolue, l'ancienne image reste.
  Future<VisualVersion> generateVisual(
    String projectId, {
    required String style,
    List<String> modifications = const [],
    String? newModification,
  }) async {
    final generator = imageGenerator;
    final p = data.projectById(projectId);
    if (generator == null) throw StateError('Aucun service d\'images configuré.');
    if (p == null) throw StateError('Projet introuvable.');
    final mods = [...modifications, if (newModification != null && newModification.trim().isNotEmpty) newModification.trim()];
    final prompt = buildVisualPrompt(p, style, mods);
    _pendingAi++;
    notifyListeners();
    try {
      final bytes = await generator.generate(prompt);
      final version = VisualVersion(style: style, modifications: mods, prompt: prompt, filePath: '', provider: generator.name);
      final path = await storageService.saveImage(projectId, version.id, bytes);
      final saved = VisualVersion(
        id: version.id,
        style: style,
        modifications: mods,
        prompt: prompt,
        filePath: path,
        provider: generator.name,
      );
      final current = data.projectById(projectId) ?? p;
      current.visuals = [...current.visuals, saved];
      if (newModification != null && newModification.trim().isNotEmpty) {
        current.designNotes = [...current.designNotes, 'Aperçu : ${newModification.trim()}'];
      }
      current.touch();
      _replaceProject(current);
      await _persist();
      return saved;
    } finally {
      _pendingAi--;
      notifyListeners();
    }
  }

  Future<void> deleteVisual(String projectId, String visualId) async {
    final p = data.projectById(projectId);
    if (p == null) return;
    final v = p.visuals.where((e) => e.id == visualId).firstOrNull;
    if (v == null) return;
    try {
      await storageService.deleteFile(v.filePath);
    } catch (_) {}
    p.visuals = [for (final e in p.visuals) if (e.id != visualId) e];
    _replaceProject(p);
    await _persist();
    notifyListeners();
  }

  /// Transforme un concept choisi en projet (sans appel à l'IA) et renvoie
  /// l'id du projet créé.
  String adoptConcept(InventionConcept concept) {
    final project = concept.toProject();
    data = data.copyWith(
      projects: [...data.projects, project],
      journal: [
        ...data.journal,
        JournalEntry(
          id: _uuid.v4(),
          text: 'Concept choisi : ${concept.name}.',
          projectId: project.id,
        ),
      ],
    );
    _persist();
    notifyListeners();
    return project.id;
  }

  static final _constraintPattern = RegExp(
      r"^(?:je n'ai que|j'ai seulement|je n'ai pas de|je n'ai plus de|je veux eviter|j'aimerais eviter|"
      r"je prefere|je voudrais eviter|sans |pas de |il faut que|ca doit|il doit|elle doit|"
      r"pas plus de|moins de|au maximum|maximum )");

  /// Mémorise une contrainte exprimée sur le projet en cours (« je n'ai que
  /// quatre boîtes », « je veux éviter la soudure ») : elle accompagne ensuite
  /// le projet dans chaque demande à l'IA.
  void _rememberConstraint(InventionProject p, String text) {
    final t = text.trim();
    if (t.isEmpty || t.length > 240) return;
    if (!_constraintPattern.hasMatch(_normalize(t))) return;
    if (p.designNotes.contains(t)) return;
    p.designNotes = [...p.designNotes, t];
    _replaceProject(p);
  }

  static String _normalize(String s) {
    const from = 'àáâäãåçèéêëìíîïòóôöõùúûüýÿñ';
    const to = 'aaaaaaceeeeiiiiooooouuuuyyn';
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    return b.toString();
  }

  static const _ordinals = {
    1: r'premier|premiere|1er|1re|1ere|un|une|1',
    2: r'deuxieme|second|seconde|2e|2eme|deux|2',
    3: r'troisieme|3e|3eme|trois|3',
    4: r'quatrieme|4e|4eme|4',
    5: r'cinquieme|5e|5eme|5',
    6: r'sixieme|6e|6eme|6',
  };

  /// Concept désigné dans [text] parmi ceux de la dernière proposition :
  /// par son rang (« le deuxième », « le 2 ») ou par son nom.
  InventionConcept? conceptReferencedIn(String text) {
    // Uniquement la proposition la plus récente.
    final lastTurn = data.chats.reversed
        .where((t) => !t.isUser && conceptsFromJson(t.payload?['concepts']).isNotEmpty)
        .firstOrNull;
    if (lastTurn == null) return null;
    final latest = conceptsFromJson(lastTurn.payload?['concepts']);
    final n = _normalize(text);
    for (final c in latest) {
      if (c.name.length > 3 && n.contains(_normalize(c.name))) return c;
    }
    for (final e in _ordinals.entries) {
      final re = RegExp(
          r"(?:\b(?:le|la|l'|numero|n°|no|choix|proposition|variante|concept|option)\s*(?:" +
              e.value +
              r")\b)|(?:^\s*(?:" +
              e.value +
              r")\b)");
      if (re.hasMatch(n) && e.key <= latest.length) return latest[e.key - 1];
    }
    return null;
  }

  NabuAiResponse? _resolveConceptChoice(String text) {
    final n = _normalize(text);
    if (!RegExp(r'plait|choisi|prends|prendre|retiens|garde|veux|prefere|va pour|celui|celle|developpe')
        .hasMatch(n)) {
      return null;
    }
    final concept = conceptReferencedIn(text);
    if (concept == null) return null;
    final id = adoptConcept(concept);
    final response = NabuAiResponse(
      provider: provider.name,
      intent: AiIntent.invent,
      project: data.projectById(id),
      message: 'C\'est noté : « ${concept.name} » devient ton projet. Ses matériaux et repères '
          'sont repris du concept ; demande « élabore le plan » ou « fiche technique » pour la suite.',
    );
    final payload = response.toJson()..['projectId'] = id;
    data = data.copyWith(chats: [
      ...data.chats,
      ChatTurn(role: 'assistant', content: response.message, payload: payload),
    ]);
    return response;
  }

  /// Sauvegarde l'état actuel du projet avant une modification.
  void _snapshot(InventionProject p, String reason) {
    p.versions = [
      ...p.versions,
      ProjectVersion(reason: reason, snapshot: p.toSnapshotJson()),
    ];
    if (p.versions.length > maxVersions) {
      p.versions = p.versions.sublist(p.versions.length - maxVersions);
    }
  }

  static const maxVersions = 20;

  /// Revient à une version antérieure ; l'état actuel est lui-même conservé.
  void restoreVersion(String projectId, String versionId) {
    final p = data.projectById(projectId);
    if (p == null) return;
    final v = p.versions.where((e) => e.id == versionId).firstOrNull;
    if (v == null) return;
    _snapshot(p, 'Avant le retour à la version du ${v.createdAt.day}/${v.createdAt.month}');
    final restored = InventionProject.fromJson({...v.snapshot, 'id': p.id})
      ..versions = p.versions
      ..visuals = p.visuals
      ..touch();
    _replaceProject(restored);
    _persist();
    notifyListeners();
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
      turns.add(AiTurn(t.role, t.isUser ? t.content : _assistantContextText(t)));
    }
    return turns.length > 10 ? turns.sublist(turns.length - 10) : turns;
  }

  /// Texte d'un tour assistant renvoyé au modèle : le message, plus la liste
  /// numérotée des concepts proposés, pour que « le deuxième me plaît » ou
  /// « le héron minimaliste » puissent être compris.
  String _assistantContextText(ChatTurn t) {
    final concepts = conceptsFromJson(t.payload?['concepts']);
    if (concepts.isEmpty) return t.content;
    final b = StringBuffer(t.content)..writeln()..writeln('Concepts proposés :');
    for (var i = 0; i < concepts.length; i++) {
      final c = concepts[i];
      b.writeln('${i + 1}. ${c.subject.isEmpty ? '' : '[${c.subject}] '}${c.name}'
          '${c.style.isEmpty ? '' : ' — ${c.style}'} : ${c.description}');
    }
    return b.toString().trimRight();
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
      case AiIntent.techsheet when r.techSheet != null:
        final target = data.projectById(project?.id) ?? active;
        if (target != null) {
          applyTechSheet(target.id, r.techSheet!, persist: false);
          projectId = target.id;
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
    _snapshot(target, plan != null && plan.steps.isNotEmpty
        ? 'Avant le nouveau plan proposé par l\'IA'
        : 'Avant la mise à jour par l\'IA');
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

  /// Intègre une fiche technique au projet. Les mesures déjà saisies par
  /// l'utilisateur ne sont jamais remplacées par des hypothèses.
  void applyTechSheet(String projectId, TechSheet proposal, {bool persist = true}) {
    final p = data.projectById(projectId);
    if (p == null) return;
    if (p.tech != null) _snapshot(p, 'Avant la fiche technique proposée par l\'IA');
    p.tech = p.tech == null ? proposal.copy() : p.tech!.mergedWith(proposal);
    p.touch();
    _replaceProject(p);
    if (persist) {
      _persist();
      notifyListeners();
    }
  }

  /// Supprime la fiche technique (une copie reste dans les versions).
  void clearTechSheet(String projectId) {
    final p = data.projectById(projectId);
    if (p == null || p.tech == null) return;
    _snapshot(p, 'Avant la suppression de la fiche technique');
    p.tech = null;
    p.touch();
    _replaceProject(p);
    _persist();
    notifyListeners();
  }

  /// Remplace la fiche technique après modification par l'utilisateur.
  void updateTechSheet(String projectId, TechSheet sheet) {
    final p = data.projectById(projectId);
    if (p == null) return;
    p.tech = sheet;
    p.touch();
    _replaceProject(p);
    _persist();
    notifyListeners();
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

  /// Mémorise l'étape affichée dans le mode « On le fabrique ! ».
  void setCurrentStep(String projectId, int index) {
    final p = data.projectById(projectId);
    if (p == null || p.currentStep == index) return;
    p.currentStep = index;
    _replaceProject(p);
    _persist();
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