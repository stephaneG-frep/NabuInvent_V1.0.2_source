import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nabuinvent/ai/openai_provider.dart';

http.Response _ok() => http.Response(
      jsonEncode({
        'choices': [
          {
            'message': {'content': '{"message":"test","intent":"none"}'}
          }
        ]
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

http.Response _error(int status, String message) =>
    http.Response(jsonEncode({'error': {'message': message}}), status);

void main() {
  test('paramètre « temperature » refusé : la requête repart sans lui', () async {
    final bodies = <Map<String, dynamic>>[];
    final client = MockClient((req) async {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      bodies.add(body);
      if (body.containsKey('temperature')) {
        return _error(400, '`temperature` is deprecated for this model.');
      }
      return _ok();
    });

    final provider = OpenAICompatibleProvider(
        baseUrl: 'https://api.anthropic.com/v1', apiKey: 'k', model: 'temp-test');
    final res = await http.runWithClient(
        () => provider.respond(userText: 'test'), () => client);

    expect(res.message, 'test');
    expect(bodies.length, 2);
    expect(bodies.last.containsKey('temperature'), isFalse);
    expect(bodies.last['max_tokens'], 1800);

    // L'ajustement est mémorisé : la requête suivante part directement sans.
    await http.runWithClient(() => provider.respond(userText: 'test'), () => client);
    expect(bodies.length, 3);
  });

  test('« max_tokens » remplacé par « max_completion_tokens »', () async {
    final bodies = <Map<String, dynamic>>[];
    final client = MockClient((req) async {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      bodies.add(body);
      if (body.containsKey('max_tokens')) {
        return _error(400,
            "Unsupported parameter: 'max_tokens' is not supported with this model. "
            "Use 'max_completion_tokens' instead.");
      }
      return _ok();
    });

    final provider = OpenAICompatibleProvider(apiKey: 'k', model: 'tokens-test');
    await http.runWithClient(() => provider.respond(userText: 'test'), () => client);

    expect(bodies.last['max_completion_tokens'], 1800);
    expect(bodies.last.containsKey('max_tokens'), isFalse);
  });

  test('clé refusée : message clair, pas de nouvel essai', () async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      return _error(401, 'Invalid Anthropic API Key');
    });
    final provider = OpenAICompatibleProvider(apiKey: 'k', model: 'key-test');

    await expectLater(
      http.runWithClient(() => provider.respond(userText: 'test'), () => client),
      throwsA(isA<AiHttpException>()
          .having((e) => e.hint, 'hint', contains('Clé API refusée'))),
    );
    expect(calls, 1);
  });

  test('un paramètre refusé n\'est pas présenté comme un modèle introuvable', () {
    const e = AiHttpException(400, '`temperature` is deprecated for this model.');
    expect(e.hint, isNot(contains('Modèle introuvable')));
    const notFound = AiHttpException(404, 'model: claude-x not found');
    expect(notFound.hint, contains('Modèle introuvable'));
  });
}
