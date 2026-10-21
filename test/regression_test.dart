import 'package:flutter_test/flutter_test.dart';
import 'package:nabuinvent/ai/ai_provider.dart';
import 'package:nabuinvent/ai/ai_response.dart';
import 'package:nabuinvent/ai/offline_engine.dart';
import 'package:nabuinvent/models/app_data.dart';
import 'package:nabuinvent/models/invention_project.dart';
import 'package:nabuinvent/services/settings_service.dart';
import 'package:nabuinvent/services/storage_service.dart';
import 'package:nabuinvent/state/app_state.dart';

class _MemoryStorage extends StorageService {
  int saves = 0;
  @override
  Future<void> save(AppData data) async => saves++;
}

class _MemorySettings extends SettingsService {
  @override
  Future<void> save(AppSettings settings) async {}
}

/// Fournisseur factice : renvoie la réponse JSON donnée, comme un modèle cloud.
class _FakeProvider extends AiProvider {
  String reply;
  final List<List<AiTurn>> histories = [];
  _FakeProvider(this.reply);

  @override
  String get name => 'fake';
  @override
  bool get isCloud => true;
  @override
  bool get isConfigured => true;

  @override
  Future<NabuAiResponse> respond({
    required String userText,
    List<AiTurn> history = const [],
    String? projectContext,
  }) async {
    histories.add(history);
    return NabuAiResponse.parse(reply, name);
  }
}

AppState _state(AiProvider provider, {List<InventionProject>? projects}) {
  final app = AppState(
    settingsService: _MemorySettings(),
    storageService: _MemoryStorage(),
  );
  app.provider = provider;
  app.data = AppData(projects: projects);
  return app;
}

InventionProject _existing() => InventionProject(
      id: 'p1',
      title: 'Lampe de bureau',
      problem: 'Éclairer le bureau',
      status: ProjectStatus.building,
      starred: true,
      plan: ProjectPlan(steps: [
        PlanStep(id: 's1', title: 'Découper', detail: '', done: true),
        PlanStep(id: 's2', title: 'Monter', detail: ''),
      ]),
    );

void main() {
  group('Moteur local — détection d\'intention', () {
    final engine = OfflineEngine();

    Future<AiIntent> intentOf(String text) async =>
        (await engine.respond(userText: text)).intent;

    test('« plantes » / « planche » ne déclenchent pas un plan', () async {
      expect(await intentOf('Invente un arrosoir automatique pour mes plantes'),
          AiIntent.invent);
      expect(await intentOf('Un arroseur automatique pour mes plantes pendant les vacances.'),
          AiIntent.invent);
      expect(await intentOf('Une planche à découper intelligente pour la cuisine'),
          AiIntent.invent);
    });

    test('« réaliser » (exemple du README) ne déclenche pas un plan', () async {
      expect(await intentOf('Écris-moi une idée facile à réaliser'), AiIntent.invent);
    });

    test('une salutation suivie d\'une demande est traitée', () async {
      expect(await intentOf('Bonjour, invente-moi une lampe pour mon bureau'),
          AiIntent.invent);
      expect(await intentOf('Bonjour !'), AiIntent.none);
    });

    test('inventer à partir d\'une étincelle produit une invention', () async {
      expect(
          await intentOf('Conçois une invention à partir de cette étincelle : '
              'Lampe-défi — un défi lumineux'),
          AiIntent.invent);
    });

    test('les demandes du Studio restent reconnues', () async {
      expect(await intentOf('Élabore le plan de construction détaillé de ce projet, étape par étape.'),
          AiIntent.plan);
      expect(await intentOf('Évalue cette idée de projet.'), AiIntent.evaluate);
      expect(await intentOf('Donne-moi une étincelle créative.'), AiIntent.spark);
      expect(await intentOf('Écris dans mon journal : le moteur tourne'), AiIntent.journal);
    });

    test('une invention avec un projet actif ne reprend pas son id', () async {
      final res = await engine.respond(
        userText: 'Invente un objet pour le jardin',
        projectContext: '{"id":"p1","title":"Lampe de bureau"}',
      );
      expect(res.project!.id, isNot('p1'));
    });

    test('un plan avec un projet actif porte sur ce projet', () async {
      final res = await engine.respond(
        userText: 'Élabore le plan pour le jardin',
        projectContext: '{"id":"p1","title":"Lampe de bureau","materials":["ampoule"]}',
      );
      expect(res.project!.id, 'p1');
      expect(res.project!.title, 'Lampe de bureau');
      expect(res.project!.materials, ['ampoule']);
    });
  });

  group('Parsing des réponses cloud', () {
    test('nombres renvoyés en chaîne ou en décimal', () {
      final r = NabuAiResponse.parse(
          '{"message":"ok","intent":"invent","project":{"title":"X",'
          '"difficulty":"3","score":7.6,"materials":"bois"}}',
          'c');
      expect(r.intent, AiIntent.invent);
      expect(r.project!.difficulty, 3);
      expect(r.project!.score, 8);
      expect(r.project!.materials, ['bois']);
    });

    test('difficulté hors bornes ramenée entre 1 et 5', () {
      final r = NabuAiResponse.parse(
          '{"message":"ok","intent":"invent","project":{"title":"X","difficulty":9}}', 'c');
      expect(r.project!.difficulty, 5);
    });

    test('les étapes sans id reçoivent des ids uniques', () {
      final r = NabuAiResponse.parse(
          '{"message":"ok","intent":"plan","plan":{"steps":[{"title":"a"},{"title":"b"},'
          '{"id":"x","title":"c"},{"id":"x","title":"d"}]}}',
          'c');
      final ids = r.plan!.steps.map((s) => s.id).toList();
      expect(ids.every((id) => id.isNotEmpty), isTrue);
      expect(ids.toSet().length, ids.length);
    });

    test('un plan seulement dans project.plan est récupéré', () {
      final r = NabuAiResponse.parse(
          '{"message":"ok","intent":"plan","project":{"title":"X",'
          '"plan":{"steps":[{"title":"a"}]}}}',
          'c');
      expect(r.plan!.steps.length, 1);
    });

    test('l\'historique n\'est pas recopié dans le message utilisateur', () {
      final content = AiContract.buildUserContent(userText: 'Bonjour');
      expect(content, isNot(contains('Historique')));
    });
  });

  group('AppState — application des réponses', () {
    test('une invention avec un projet actif crée un nouveau projet', () async {
      final provider = _FakeProvider(
          '{"message":"ok","intent":"invent","project":{"id":"p1","title":"Nouvelle idée"}}');
      final app = _state(provider, projects: [_existing()]);

      await app.askAi('Invente autre chose', activeProjectId: 'p1');

      expect(app.data.projects.length, 2);
      final old = app.data.projectById('p1')!;
      expect(old.title, 'Lampe de bureau');
      expect(old.status, ProjectStatus.building);
      expect(old.starred, isTrue);
      expect(old.plan.steps.length, 2);
    });

    test('un plan cloud sans "project" s\'attache au projet actif', () async {
      final provider = _FakeProvider(
          '{"message":"ok","intent":"plan","plan":{"steps":[{"title":"a"},{"title":"b"},{"title":"c"}]}}');
      final p = _existing()
        ..status = ProjectStatus.idea
        ..plan = ProjectPlan();
      final app = _state(provider, projects: [p]);

      await app.askAi('Fais le plan', activeProjectId: 'p1');

      expect(app.data.projects.length, 1);
      final updated = app.data.projectById('p1')!;
      expect(updated.plan.steps.length, 3);
      expect(updated.status, ProjectStatus.plan);
      expect(updated.title, 'Lampe de bureau');
    });

    test('un plan cloud sans projet ni projet actif crée un projet', () async {
      final provider = _FakeProvider(
          '{"message":"ok","intent":"plan","plan":{"steps":[{"title":"a"}]}}');
      final app = _state(provider);

      await app.askAi('Plan pour un nichoir');

      expect(app.data.projects.single.title, 'Plan pour un nichoir');
      expect(app.data.projects.single.plan.steps.length, 1);
    });

    test('cocher une étape d\'un plan cloud ne coche qu\'elle', () async {
      final provider = _FakeProvider(
          '{"message":"ok","intent":"plan","plan":{"steps":[{"title":"a"},{"title":"b"}]}}');
      final app = _state(provider);
      await app.askAi('Plan pour un nichoir');
      final p = app.data.projects.single;

      app.toggleStepDone(p.id, p.plan.steps.first.id);

      expect(app.data.projectById(p.id)!.plan.completedCount, 1);
    });

    test('le message utilisateur s\'affiche avant la réponse', () async {
      final provider = _FakeProvider('{"message":"ok","intent":"none"}');
      final app = _state(provider);
      var chatsAtFirstNotify = -1;
      app.addListener(() {
        if (chatsAtFirstNotify < 0) chatsAtFirstNotify = app.data.chats.length;
      });

      await app.askAi('Salut');

      expect(chatsAtFirstNotify, 1);
      expect(app.data.chats.length, 2);
    });

    test('les échanges en erreur ne sont pas renvoyés comme historique', () async {
      final provider = _FakeProvider('{"message":"ok","intent":"none"}');
      final app = _state(provider);
      await app.askAi('Question 1');
      provider.reply = '{"message":"panne","intent":"none","success":false}';
      await app.askAi('Question 2');
      provider.reply = '{"message":"ok","intent":"none"}';
      await app.askAi('Question 3');

      final sent = provider.histories.last.map((t) => t.content).toList();
      expect(sent, ['Question 1', 'ok']);
    });
  });
}
