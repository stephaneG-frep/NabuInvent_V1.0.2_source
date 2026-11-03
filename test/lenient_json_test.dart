import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nabuinvent/ai/ai_response.dart';
import 'package:nabuinvent/ai/display_reply.dart';
import 'package:nabuinvent/ai/lenient_json.dart';
import 'package:nabuinvent/models/chat_turn.dart';
import 'package:nabuinvent/widgets/rich_message.dart';

/// Réponse complète d'un modèle, telle qu'attendue par le contrat.
String _fullReply() => jsonEncode({
      'message': 'Voici une invention pour ton jardin.',
      'intent': 'invent',
      'project': {
        'title': 'Héron en boîtes de conserve',
        'concept': 'Un héron décoratif assemblé à partir de boîtes recyclées.',
        'materials': ['6 boîtes de conserve', 'fil de fer galvanisé', 'vis inox'],
        'tools': ['pince coupante', 'perceuse'],
        'budget': '≈ 12 €',
        'timeEstimate': '4 h',
        'difficulty': 3,
        'category': 'Jardin',
        'plan': {
          'steps': [
            for (var i = 1; i <= 8; i++)
              {
                'title': 'Étape $i',
                'detail': 'Description détaillée de l\'étape $i. ' * 6,
                'safety': 'Porte des gants.',
              }
          ]
        },
      },
    });

void main() {
  group('LenientJson', () {
    test('JSON complet entouré de texte et de blocs ```json', () {
      final r = LenientJson.decodeObject('Voici :\n```json\n${_fullReply()}\n```\nBonne fabrication !');
      expect(r.map, isNotNull);
      expect(r.repaired, isFalse);
    });

    test('virgules finales', () {
      final r = LenientJson.decodeObject('{"message":"ok","materials":["a","b",],}');
      expect(r.map!['materials'], ['a', 'b']);
      expect(r.repaired, isTrue);
    });

    test('réponse tronquée à n\'importe quel endroit : toujours un objet', () {
      final full = _fullReply();
      for (var cut = 40; cut < full.length; cut += 37) {
        final r = LenientJson.decodeObject(full.substring(0, cut));
        expect(r.map, isNotNull, reason: 'coupe à $cut');
        expect(r.map!['message'], isA<String>(), reason: 'coupe à $cut');
      }
    });

    test('extraction du message d\'un texte illisible', () {
      expect(LenientJson.extractMessage('{"message":"Bonjour \\"toi\\"", "intent": inv'),
          'Bonjour "toi"');
    });
  });

  group('NabuAiResponse.parse — jamais de JSON brut affiché', () {
    test('réponse tronquée : fiche récupérée, message lisible', () {
      final full = _fullReply();
      final r = NabuAiResponse.parse(full.substring(0, (full.length * 0.7).round()), 'test');
      expect(r.message, isNot(contains('"materials"')));
      expect(r.message.trimLeft().startsWith('{'), isFalse);
      expect(r.project!.title, 'Héron en boîtes de conserve');
      expect(r.project!.materials, contains('fil de fer galvanisé'));
      expect(r.partial, isTrue);
      expect(r.raw, isNotNull);
    });

    test('réponse coupée avant même le message : texte d\'explication', () {
      final r = NabuAiResponse.parse('{"intent":"invent","project":{"title":"Can', 'test');
      expect(r.message, isNot(contains('{')));
      expect(r.project!.title, 'Can');
    });

    test('JSON totalement illisible : message explicatif, pas le JSON', () {
      final r = NabuAiResponse.parse('{{{ "materials": [ ### ', 'test');
      expect(r.message, isNot(contains('materials')));
      expect(r.partial, isTrue);
    });

    test('le texte brut conservé masque les clés API', () {
      final r = NabuAiResponse.parse(
          '{"message":"clé sk-abcdefghijklmnopqrstu utilisée","intent":"none"}', 'test');
      expect(r.raw, isNot(contains('sk-abcdefghijklmnopqrstu')));
    });

    test('texte simple : conservé tel quel, sans texte brut en double', () {
      final r = NabuAiResponse.parse('## Idée\n- une lampe', 'test');
      expect(r.message, '## Idée\n- une lampe');
      expect(r.raw, isNull);
    });
  });

  group('DisplayReply', () {
    test('ancienne réponse enregistrée en JSON brut : ré-interprétée', () {
      final full = _fullReply();
      final turn = ChatTurn(
        role: 'assistant',
        content: full.substring(0, full.length - 300),
        payload: {'provider': 'cloud', 'intent': 'none', 'success': true},
      );
      final d = DisplayReply.fromTurn(turn);
      expect(d.message.contains('"materials"'), isFalse);
      expect(d.project!.title, 'Héron en boîtes de conserve');
      expect(d.raw, isNotNull);
    });

    test('réponse moderne : données du payload', () {
      final r = NabuAiResponse.parse(_fullReply(), 'cloud');
      final turn = ChatTurn(role: 'assistant', content: r.message, payload: r.toJson());
      final d = DisplayReply.fromTurn(turn);
      expect(d.message, 'Voici une invention pour ton jardin.');
      expect(d.project!.plan.steps.length, 8);
    });
  });

  group('parseRichBlocks', () {
    test('titres, listes, paragraphes', () {
      final blocks = parseRichBlocks('# Titre\nPremière ligne\nsuite\n\n- un\n* deux\n2. trois\n> note');
      expect(blocks.map((b) => b.kind).toList(), [
        RichBlockKind.heading1,
        RichBlockKind.paragraph,
        RichBlockKind.bullet,
        RichBlockKind.bullet,
        RichBlockKind.numbered,
        RichBlockKind.quote,
      ]);
      expect(blocks[1].text, 'Première ligne\nsuite');
      expect(blocks[4].marker, '2.');
    });
  });
}
