import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nabuinvent/ai/ai_provider.dart';
import 'package:nabuinvent/ai/ai_response.dart';
import 'package:nabuinvent/ai/image_generator.dart';
import 'package:nabuinvent/ai/offline_engine.dart';
import 'package:nabuinvent/export/project_exporter.dart';
import 'package:nabuinvent/models/app_data.dart';
import 'package:nabuinvent/models/invention_project.dart';
import 'package:nabuinvent/models/tech_sheet.dart';
import 'package:nabuinvent/services/settings_service.dart';
import 'package:nabuinvent/services/storage_service.dart';
import 'package:nabuinvent/state/app_state.dart';
import 'package:nabuinvent/tech/material_calculator.dart';
import 'package:nabuinvent/tech/safety_checker.dart';
import 'package:nabuinvent/tech/tech_sheet_builder.dart';
import 'package:nabuinvent/widgets/tech_drawings.dart';

class _MemoryStorage extends StorageService {
  @override
  Future<void> save(AppData data) async {}
}

class _MemorySettings extends SettingsService {
  @override
  Future<void> save(AppSettings settings) async {}
}

class _FakeProvider extends AiProvider {
  String reply;
  _FakeProvider(this.reply);
  @override
  String get name => 'fake';
  @override
  bool get isCloud => true;
  @override
  bool get isConfigured => true;
  @override
  Future<NabuAiResponse> respond(
          {required String userText, List<AiTurn> history = const [], String? projectContext, Future<void>? cancel}) async =>
      NabuAiResponse.parse(reply, name);
}

AppState _app({AiProvider? provider, List<InventionProject>? projects}) {
  final app = AppState(settingsService: _MemorySettings(), storageService: _MemoryStorage());
  if (provider != null) app.provider = provider;
  app.data = AppData(projects: projects);
  return app;
}

TechSheet _heronSheet({DataSource source = DataSource.user}) => TechSheet(parts: [
      TechPart(name: 'Socle', material: 'Planche pin', shape: PartShape.box, length: 300, width: 200, thickness: 18, source: source),
      TechPart(name: 'Pattes', material: 'Tige filetée', shape: PartShape.bar, quantity: 2, length: 600, x: 120, y: 18, source: source),
      TechPart(name: 'Corps', material: 'Boîte de conserve', shape: PartShape.cylinder, length: 110, width: 74, x: 110, y: 600, source: source),
    ]);

void main() {
  group('Calculateur de matériaux', () {
    test('plan de découpe : premier ajustement décroissant, trait de scie, chutes', () {
      final plan = MaterialCalculator.planLinearCuts([1200, 800, 800, 600, 400],
          stockLength: 2400, kerf: 3);
      expect(plan.barCount, 2);
      expect(plan.bars.first.pieces, [1200, 800]);
      expect(plan.bars[1].pieces, [800, 600, 400]);
      // 2400 - (1200 + 800 + 2 × 3)
      expect(plan.bars.first.offcut, 394);
      expect(plan.tooLong, isEmpty);
    });

    test('pièce plus longue qu\'une barre : signalée, jamais coupée', () {
      final plan = MaterialCalculator.planLinearCuts([3000, 500], stockLength: 2400);
      expect(plan.tooLong, [3000]);
      expect(plan.barCount, 1);
    });

    test('tôle de conserves : surface et nombre de boîtes', () {
      // Boîte Ø 74 × 110 mm : surface latérale ≈ 25 572 mm².
      expect(MaterialCalculator.cylinderLateralArea(74, 110), closeTo(25572.1, 0.5));
      // 100 000 mm² avec 80 % utilisable → 5 boîtes.
      expect(MaterialCalculator.cansForSheetArea(100000, canDiameter: 74, canHeight: 110), 5);
    });

    test('quantités, découpe et budget à partir de la nomenclature', () {
      final sheet = _heronSheet()
        ..parts[0].unitPrice = 6
        ..parts[1].unitPrice = 2.5;
      final lines = MaterialCalculator.summarize(sheet);
      final rod = lines.firstWhere((l) => l.material == 'Tige filetée');
      expect(rod.pieceCount, 2);
      expect(rod.linearMm, 1200);
      final board = lines.firstWhere((l) => l.material == 'Planche pin');
      expect(board.volumeMm3, 300 * 200 * 18);
      expect(MaterialCalculator.cutPlans(sheet)['Tige filetée']!.barCount, 1);
      final budget = MaterialCalculator.budget(sheet);
      expect(budget.knownTotal, 6 + 2 * 2.5);
      expect(budget.unpricedLines, 1);
    });
  });

  group('Fiche technique', () {
    test('état du plan : incomplet → hypothèses → vérifié', () {
      final sheet = _heronSheet(source: DataSource.ai);
      expect(sheet.readiness, PlanReadiness.hypothetical);
      sheet.parts[0].thickness = null;
      expect(sheet.readiness, PlanReadiness.incomplete);
      expect(sheet.missingMeasurements, ['Socle : épaisseur']);
      sheet.parts[0].thickness = 18;
      for (final p in sheet.parts) {
        p.source = DataSource.user;
      }
      expect(sheet.readiness, PlanReadiness.ready);
    });

    test('une proposition de l\'IA n\'écrase jamais une mesure de l\'utilisateur', () {
      final mine = _heronSheet();
      final proposal = TechSheet(parts: [
        TechPart(name: 'socle', shape: PartShape.box, length: 999, width: 999, thickness: 99),
        TechPart(name: 'Bec', shape: PartShape.sheet, length: 80, width: 20, thickness: 0.3),
      ]);
      final merged = mine.mergedWith(proposal);
      final socle = merged.parts.firstWhere((p) => p.name.toLowerCase() == 'socle');
      expect(socle.length, 300);
      expect(socle.source, DataSource.user);
      expect(merged.parts.any((p) => p.name == 'Bec' && p.source == DataSource.ai), isTrue);
      // Pièces mesurées absentes de la proposition : conservées.
      expect(merged.parts.any((p) => p.name == 'Pattes'), isTrue);
    });

    test('fiche de départ sans IA : aucune cote inventée', () {
      final p = InventionProject(id: 'p', title: 'Héron', materials: [
        '4 boîtes de conserve', 'tige filetée M6', 'vis inox', 'peinture extérieure'
      ]);
      final sheet = TechSheetBuilder.fromProject(p);
      expect(sheet.parts.map((e) => e.shape), [PartShape.cylinder, PartShape.bar]);
      expect(sheet.parts.first.quantity, 4);
      expect(sheet.parts.every((e) => e.length == null && e.source == DataSource.unknown), isTrue);
      expect(sheet.fasteners, ['vis inox']);
      expect(sheet.finishes, ['peinture extérieure']);
      expect(sheet.readiness, PlanReadiness.incomplete);
    });

    test('réponse IA « techsheet » appliquée au projet actif, mesures conservées', () async {
      final project = InventionProject(id: 'p1', title: 'Héron')..tech = _heronSheet();
      final reply = jsonEncode({
        'message': 'Fiche prête.',
        'intent': 'techsheet',
        'techSheet': {
          'parts': [
            {'name': 'Socle', 'shape': 'box', 'length': 500, 'width': 500, 'thickness': 30, 'source': 'ai'},
            {'name': 'Cou', 'shape': 'bar', 'length': '350 mm', 'source': 'ai'},
          ],
          'unknowns': ['Hauteur souhaitée'],
        },
      });
      final app = _app(provider: _FakeProvider(reply), projects: [project]);
      await app.askAi('Fiche technique', activeProjectId: 'p1');
      final tech = app.data.projectById('p1')!.tech!;
      expect(tech.parts.firstWhere((e) => e.name == 'Socle').length, 300);
      expect(tech.parts.firstWhere((e) => e.name == 'Cou').length, 350);
      expect(app.data.projectById('p1')!.versions, isNotEmpty);
    });

    test('moteur local : fiche technique du projet en cours', () async {
      final r = await OfflineEngine().respond(
        userText: 'Prépare la fiche technique',
        projectContext: jsonEncode(InventionProject(id: 'p', title: 'Lampe', materials: ['planche de pin']).toJson()),
      );
      expect(r.intent, AiIntent.techsheet);
      expect(r.techSheet!.parts.single.length, isNull);
    });

    test('vues : projection déterministe des pièces cotées', () {
      final parts = _heronSheet().parts;
      final front = projectParts(parts, TechView.front);
      expect(front.length, 3);
      // Socle à plat : 300 de large, 18 de haut ; pattes debout : 600 de haut.
      final socle = front.first.rect;
      expect(socle.width, 300);
      expect(socle.height, 18);
      expect(front[1].rect.height, 600);
      // Vue de dessus : le socle occupe 300 × 200.
      final top = projectParts(parts, TechView.top);
      expect(top.first.rect.width, 300);
      expect(top.first.rect.height, 200);
      // Pièce incomplète : non dessinée.
      parts[1].length = null;
      expect(projectParts(parts, TechView.front).length, 2);
    });
  });

  group('Sécurité', () {
    test('boîtes de conserve au jardin', () {
      final f = SafetyChecker.check(materials: ['boîtes de conserve', 'vis'], text: 'héron pour le jardin');
      final topics = f.map((e) => e.topic).toList();
      expect(topics, containsAll(['Bords coupants', 'Récipients réutilisés', 'Corrosion', 'Eau stagnante']));
      expect(f.firstWhere((e) => e.topic == 'Bords coupants').advice, contains('gants'));
    });

    test('validation professionnelle : charge humaine et 230 V', () {
      expect(SafetyChecker.check(text: 'une balançoire en bois').any((e) => e.level == SafetyLevel.professional), isTrue);
      expect(SafetyChecker.check(text: 'lampe branchée sur le secteur 230 V').any((e) => e.level == SafetyLevel.professional), isTrue);
    });

    test('jamais d\'affirmation de sécurité', () {
      final all = SafetyChecker.check(materials: ['bois'], text: 'jardinière').map((e) => e.text).join(' ');
      expect(all.toLowerCase(), isNot(contains('est sûr')));
      expect(SafetyChecker.disclaimer, contains('ne garantissent'));
    });
  });

  group('Mémoire du projet', () {
    test('contraintes mémorisées et versions restaurables', () async {
      final project = InventionProject(id: 'p1', title: 'Héron', materials: ['6 boîtes']);
      final reply = jsonEncode({
        'message': 'Adapté.',
        'intent': 'refine',
        'project': {'id': 'p1', 'title': 'Héron sans soudure', 'materials': ['4 boîtes', 'rivets']},
      });
      final app = _app(provider: _FakeProvider(reply), projects: [project]);
      await app.askAi('Je n\'ai que quatre boîtes.', activeProjectId: 'p1');
      await app.askAi('Je veux éviter la soudure.', activeProjectId: 'p1');
      final p = app.data.projectById('p1')!;
      expect(p.designNotes, ['Je n\'ai que quatre boîtes.', 'Je veux éviter la soudure.']);
      expect(p.title, 'Héron sans soudure');
      expect(p.versions.length, 2);

      app.restoreVersion('p1', p.versions.first.id);
      final restored = app.data.projectById('p1')!;
      expect(restored.title, 'Héron');
      expect(restored.materials, ['6 boîtes']);
      // L'état d'avant la restauration est lui-même conservé.
      expect(restored.versions.length, 3);
      expect(restored.versions.last.title, 'Héron sans soudure');
    });

    test('mode local : « le deuxième me plaît » crée le projet du 2e concept', () async {
      final app = _app();
      await app.askAi('Je voudrais fabriquer un héron avec des boîtes de conserve.');
      final r = await app.askAi('Le deuxième me plaît.');
      expect(r.project!.title, 'Héron articulé');
      expect(app.data.projects.single.title, 'Héron articulé');
      expect(app.data.chats.last.payload!['projectId'], app.data.projects.single.id);
    });
  });

  group('Studio visuel', () {
    test('prompt cohérent avec le projet, les contraintes et les modifications', () {
      final p = InventionProject(id: 'p', title: 'Héron', concept: 'Héron décoratif',
          materials: ['boîtes de conserve'], designNotes: ['sans soudure']);
      final prompt = buildVisualPrompt(p, 'Industriel', ['Allonge le cou du héron']);
      expect(prompt, contains('boîtes de conserve'));
      expect(prompt, contains('sans soudure'));
      expect(prompt, contains('Allonge le cou du héron'));
      expect(prompt, contains('métal brut'));
    });

    test('vrai appel /images/generations ; paramètre refusé retiré', () async {
      final bodies = <Map<String, dynamic>>[];
      final client = MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        bodies.add(body);
        expect(req.url.path, endsWith('/images/generations'));
        if (body.containsKey('response_format')) {
          return http.Response(jsonEncode({'error': {'message': "Unknown parameter: 'response_format'."}}), 400);
        }
        return http.Response(jsonEncode({'data': [{'b64_json': base64Encode([137, 80, 78, 71])}]}), 200);
      });
      final g = OpenAIImageGenerator(baseUrl: 'https://api.openai.com/v1', apiKey: 'k', model: 'img-test');
      final bytes = await http.runWithClient(() => g.generate('un héron'), () => client);
      expect(bytes, [137, 80, 78, 71]);
      expect(bodies.length, 2);
      expect(bodies.last['model'], 'img-test');
    });

    test('sans service configuré : aucune génération', () {
      expect(_app().imageGenerator, isNull);
    });
  });

  group('Exports', () {
    InventionProject project() => InventionProject(
          id: 'p',
          title: 'Héron métallique',
          concept: 'Héron décoratif ≈ 70 cm',
          materials: ['boîtes de conserve', 'tige filetée'],
          plan: ProjectPlan(steps: [PlanStep(id: 's1', title: 'Ébavurer', detail: 'Lime les bords.', safety: 'Gants.')]),
        )..tech = _heronSheet();

    test('JSON structuré avec calculs et sécurité', () {
      final json = ProjectExporter.projectJson(project());
      expect(json['format'], 'nabuinvent-projet');
      expect((json['calculs'] as Map)['etatDuPlan'], PlanReadiness.ready.label);
      expect(json['securite'], isNotEmpty);
      // Réimportable : le projet se relit à l'identique.
      final again = InventionProject.fromJson(json['project'] as Map<String, dynamic>);
      expect(again.tech!.parts.length, 3);
    });

    testWidgets('PDF, PNG et ZIP réellement produits', (tester) async {
      await tester.runAsync(() async {
        final p = project();
        final png = await ProjectExporter.renderViewPng(p.tech!, TechView.front, size: 300);
        expect(png.sublist(0, 4), [137, 80, 78, 71]);
        final export = await ProjectExporter.build(p);
        expect(utf8.decode(export.pdf.sublist(0, 5)), '%PDF-');
        expect(export.schematics.keys, contains('vue_face.png'));
        final zip = ProjectExporter.zip(export, p);
        final names = ZipDecoder().decodeBytes(zip).files.map((f) => f.name).toList();
        expect(names, containsAll([
          'heron_metallique/projet.json',
          'heron_metallique/dossier.pdf',
          'heron_metallique/plans/vue_face.png',
        ]));
        // Contrôle visuel possible du PDF généré.
        final out = Directory.systemTemp.createTempSync('nabu_export_');
        File('${out.path}/dossier.pdf').writeAsBytesSync(export.pdf);
        File('${out.path}/vue_face.png').writeAsBytesSync(Uint8List.fromList(export.schematics['vue_face.png']!));
      });
    });
  });
}
