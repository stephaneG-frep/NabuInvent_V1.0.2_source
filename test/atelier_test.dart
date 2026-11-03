import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nabuinvent/ai/ai_provider.dart';
import 'package:nabuinvent/ai/ai_response.dart';
import 'package:nabuinvent/ai/offline_atelier.dart';
import 'package:nabuinvent/ai/offline_engine.dart';
import 'package:nabuinvent/ai/openai_provider.dart';
import 'package:nabuinvent/models/app_data.dart';
import 'package:nabuinvent/models/concept.dart';
import 'package:nabuinvent/models/material_analysis.dart';
import 'package:nabuinvent/services/settings_service.dart';
import 'package:nabuinvent/services/storage_service.dart';
import 'package:nabuinvent/state/app_state.dart';
import 'package:nabuinvent/widgets/concept_cards.dart';

class _MemoryStorage extends StorageService {
  @override
  Future<void> save(AppData data) async {}
}

class _MemorySettings extends SettingsService {
  @override
  Future<void> save(AppSettings settings) async {}
}

class _RecordingProvider extends AiProvider {
  final List<List<AiTurn>> histories = [];
  String reply = '{"message":"ok","intent":"none"}';
  @override
  String get name => 'fake';
  @override
  bool get isCloud => true;
  @override
  bool get isConfigured => true;
  @override
  Future<NabuAiResponse> respond(
      {required String userText, List<AiTurn> history = const [], String? projectContext}) async {
    histories.add(history);
    return NabuAiResponse.parse(reply, name);
  }
}

String _norm(String s) {
  const from = 'àáâäãåçèéêëìíîïòóôöõùúûüýÿñ';
  const to = 'aaaaaaceeeeiiiiooooouuuuyyn';
  return s.toLowerCase().split('').map((c) {
    final i = from.indexOf(c);
    return i >= 0 ? to[i] : c;
  }).join();
}

const _duckHeron =
    'Je veux fabriquer un canard et un héron avec des boîtes de conserve pour décorer mon jardin.';
const _resources =
    "J'ai des boîtes de conserve, du fil de fer et quelques vis. Trouve-moi quelque chose à fabriquer.";

void main() {
  group('Analyse des demandes (atelier local)', () {
    test('deux objets, un matériau, une destination', () {
      final r = OfflineAtelier.parse(_duckHeron, _norm(_duckHeron));
      expect(r.subjects, ['canard', 'héron']);
      expect(r.materials, ['boîtes de conserve']);
      expect(r.destination, 'jardin');
      expect(r.resourceMode, isFalse);
    });

    test('mode ressources : liste nettoyée', () {
      final r = OfflineAtelier.parse(_resources, _norm(_resources));
      expect(r.resourceMode, isTrue);
      expect(r.materials, ['boîtes de conserve', 'fil de fer', 'vis']);
    });

    test('quand proposer des concepts', () {
      expect(OfflineAtelier.wantsConcepts(_norm(_duckHeron)), isTrue);
      expect(OfflineAtelier.wantsConcepts(_norm(_resources)), isTrue);
      expect(OfflineAtelier.wantsConcepts(_norm('Invente un objet pour ranger les câbles.')), isFalse);
      expect(OfflineAtelier.wantsConcepts(_norm('Je veux fabriquer le plan étape par étape')), isFalse);
    });
  });

  group('Concepts du moteur local', () {
    final engine = OfflineEngine();

    test('canard et héron : 3 variantes réellement différentes par objet', () async {
      final r = await engine.respond(userText: _duckHeron);
      expect(r.intent, AiIntent.concepts);
      final groups = groupConceptsBySubject(r.concepts);
      expect(groups.keys, ['Canard', 'Héron']);
      for (final variants in groups.values) {
        expect(variants.length, 3);
        expect(variants.map((c) => c.style).toSet().length, 3);
        expect(variants.map((c) => c.name).toSet().length, 3);
        for (final c in variants) {
          expect(c.materials, contains('boîtes de conserve'));
          // Jamais de mesure présentée comme relevée.
          expect(c.dimensions, contains('indicatif'));
          // Métal de récupération : risque de coupure signalé.
          expect(c.constraints.join(' '), contains('coupants'));
        }
      }
      expect(r.message, contains('Atelier local'));
    });

    test('ressources : idées classées par faisabilité avec explication', () async {
      final r = await engine.respond(userText: _resources);
      expect(r.intent, AiIntent.concepts);
      expect(r.resources, ['boîtes de conserve', 'fil de fer', 'vis']);
      expect(r.concepts, isNotEmpty);
      final scores = r.concepts.map((c) => c.feasibility).toList();
      expect(scores, [...scores]..sort((a, b) => b.compareTo(a)));
      expect(r.concepts.every((c) => c.why.isNotEmpty), isTrue);
    });

    test('les demandes existantes ne changent pas de route', () async {
      expect((await engine.respond(userText: 'Invente un objet pour ranger les câbles du bureau.')).intent,
          AiIntent.invent);
      expect((await engine.respond(userText: 'Élabore le plan pour construire un arroseur de plantes.')).intent,
          AiIntent.plan);
    });
  });

  group('Concepts dans l\'état de l\'application', () {
    test('un concept adopté devient un projet complet', () {
      final app = AppState(settingsService: _MemorySettings(), storageService: _MemoryStorage());
      final concept = InventionConcept(
        subject: 'Héron',
        name: 'Héron minimaliste',
        style: 'Décoratif',
        description: 'Silhouette épurée.',
        materials: ['3 boîtes de conserve', 'tige filetée'],
        difficulty: 2,
        time: '≈ 3 h',
        budget: '≈ 10 €',
      );
      final id = app.adoptConcept(concept);
      final p = app.data.projectById(id)!;
      expect(p.title, 'Héron minimaliste');
      expect(p.materials, ['3 boîtes de conserve', 'tige filetée']);
      expect(p.concept, 'Silhouette épurée.');
      expect(app.data.journal.single.projectId, id);
    });

    test('« le deuxième me plaît » : le modèle reçoit la liste numérotée', () async {
      final app = AppState(settingsService: _MemorySettings(), storageService: _MemoryStorage());
      final provider = _RecordingProvider();
      app.provider = provider;
      provider.reply = jsonEncode({
        'message': 'Trois pistes pour ton héron.',
        'intent': 'concepts',
        'concepts': [
          {'subject': 'Héron', 'name': 'Héron minimaliste', 'description': 'a'},
          {'subject': 'Héron', 'name': 'Héron métallique réaliste', 'description': 'b'},
          {'subject': 'Héron', 'name': 'Héron fantaisiste', 'description': 'c'},
        ],
      });
      await app.askAi('Je voudrais fabriquer un héron avec des conserves.');
      provider.reply = '{"message":"ok","intent":"none"}';
      await app.askAi('Le deuxième me plaît.');

      final context = provider.histories.last.last.content;
      expect(context, contains('2. [Héron] Héron métallique réaliste'));
    });
  });

  group('Analyse de photo', () {
    test('requête multimodale réelle (image en base64) et réponse interprétée', () async {
      Map<String, dynamic>? sent;
      final client = MockClient((req) async {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'message': 'Je vois des boîtes et du fil.',
                    'items': [
                      {'name': 'boîtes de conserve', 'material': 'acier', 'quantity': 4, 'confidence': 92},
                      {'name': 'fil de fer', 'material': 'acier galvanisé', 'quantity': null, 'confidence': 70},
                    ],
                    'questions': ['Quelle est la hauteur des boîtes ?'],
                  })
                }
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final provider = OpenAICompatibleProvider(apiKey: 'k', model: 'vision-test');
      final analysis = await http.runWithClient(
        () => provider.analyzeMaterials(
            imageBytes: Uint8List.fromList([1, 2, 3]), mimeType: 'image/jpeg'),
        () => client,
      );

      final content = (sent!['messages'] as List).single['content'] as List;
      expect(content[1]['type'], 'image_url');
      expect(content[1]['image_url']['url'], 'data:image/jpeg;base64,AQID');
      expect(analysis.items.length, 2);
      expect(analysis.items.first.quantity, 4);
      expect(analysis.items[1].quantity, isNull);
      expect(analysis.questions, isNotEmpty);
    });

    test('liste corrigée → demande d\'idées', () {
      final items = [
        DetectedMaterial(name: 'boîtes de conserve', material: 'acier', quantity: 4, dimensions: 'Ø 7 × 11 cm'),
        DetectedMaterial(name: 'fil de fer'),
      ];
      final request = MaterialAnalysis.toResourceRequest(items);
      expect(request, contains('4 × boîtes de conserve (acier, Ø 7 × 11 cm)'));
      expect(request, contains('Trouve-moi quelque chose à fabriquer'));
    });

    test('le moteur local ne prétend pas analyser une photo', () {
      final app = AppState(settingsService: _MemorySettings(), storageService: _MemoryStorage());
      expect(app.vision, isNull);
    });
  });

  testWidgets('galerie : choisir une variante', (tester) async {
    InventionConcept? chosen;
    final concepts = OfflineAtelier.variantsFor(
        const ConceptRequest(subjects: ['canard'], materials: ['boîtes de conserve']));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ConceptGalleryCard(concepts: concepts, onChoose: (c) => chosen = c),
        ),
      ),
    ));
    expect(find.text('Canard rustique'), findsOneWidget);
    expect(find.text('Canard articulé'), findsOneWidget);
    await tester.ensureVisible(find.text('Choisir ce concept').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choisir ce concept').at(1));
    expect(chosen!.name, 'Canard articulé');
  });
}
