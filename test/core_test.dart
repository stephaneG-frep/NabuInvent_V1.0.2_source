import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nabuinvent/ai/ai_response.dart';
import 'package:nabuinvent/ai/offline_engine.dart';
import 'package:nabuinvent/models/app_data.dart';
import 'package:nabuinvent/models/invention_project.dart';

void main() {
  group('OfflineEngine', () {
    final engine = OfflineEngine();

    test('invente une invention structurée', () async {
      final res = await engine.respond(
        userText: 'Invente un objet pour ranger les câbles du bureau.',
      );
      expect(res.intent, AiIntent.invent);
      expect(res.project, isNotNull);
      expect(res.project!.title, isNotEmpty);
      expect(res.project!.materials, isNotEmpty);
      expect(res.project!.tools, isNotEmpty);
      expect(res.project!.score, greaterThan(0));
    });

    test('produit un plan avec des étapes', () async {
      final res = await engine.respond(
        userText: 'Élabore le plan pour construire un arroseur de plantes.',
      );
      expect(res.intent, AiIntent.plan);
      expect(res.plan, isNotNull);
      expect(res.plan!.steps.length, greaterThanOrEqualTo(3));
      expect(res.plan!.steps.every((s) => s.title.isNotEmpty), isTrue);
      expect(res.project!.status, ProjectStatus.plan);
    });

    test('évalue une idée avec des scores', () async {
      final res = await engine.respond(
        userText:
            'Évalue cette idée : une serre de balcon en palette recyclée avec '
            'arrosage solaire automatique.',
      );
      expect(res.intent, AiIntent.evaluate);
      expect(res.evaluation, isNotNull);
      final e = res.evaluation!;
      expect(e.originality, inInclusiveRange(0, 100));
      expect(e.feasibility, inInclusiveRange(0, 100));
      expect(e.verdict, isNotEmpty);
      expect(e.nextSteps, isNotEmpty);
    });

    test('génère une étincelle', () async {
      final res = await engine.respond(
        userText: 'Donne-moi une étincelle créative aléatoire.',
      );
      expect(res.intent, AiIntent.spark);
      expect(res.spark, isNotNull);
      expect(res.spark!.pitch, isNotEmpty);
    });

    test('comprend le journal', () async {
      final res = await engine.respond(
        userText: 'Note dans mon journal que l\'arrosage automatique fonctionne.',
      );
      expect(res.intent, AiIntent.journal);
      expect(res.journalText, isNotEmpty);
    });
  });

  group('NabuAiResponse', () {
    test('parse un JSON valide', () {
      const raw = '{"message":"Voici !","intent":"invent",'
          '"project":{"title":"L\'Objet Magique","materials":["a"],"tags":["t"]}}';
      final res = NabuAiResponse.parse(raw, 'test');
      expect(res.success, isTrue);
      expect(res.intent, AiIntent.invent);
      expect(res.project!.title, "L'Objet Magique");
    });

    test('retombe en texte seul si pas de JSON', () {
      final res = NabuAiResponse.parse('juste du texte', 'test');
      expect(res.message, 'juste du texte');
      expect(res.success, isTrue);
      expect(res.intent, AiIntent.none);
    });
  });

  group('AppData', () {
    test('encodage/décodage sans perte', () {
      final original = AppData(
        projects: [
          InventionProject(
            id: 'p1',
            title: 'Test',
            problem: 'problème',
            status: ProjectStatus.building,
            plan: ProjectPlan(
              steps: [PlanStep(id: 's1', title: 'Étape 1', detail: 'd', done: true)],
            ),
          ),
        ],
      );
      final json = jsonDecode(jsonEncode(original.toJson()));
      final copy = AppData.fromJson(json as Map<String, dynamic>);
      expect(copy.projects.length, 1);
      expect(copy.projects.first.title, 'Test');
      expect(copy.projects.first.status, ProjectStatus.building);
      expect(copy.projects.first.plan.steps.first.done, isTrue);
    });
  });
}