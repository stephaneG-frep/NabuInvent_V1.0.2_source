import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nabuinvent/ai/openai_provider.dart';
import 'package:nabuinvent/models/app_data.dart';
import 'package:nabuinvent/services/settings_service.dart';
import 'package:nabuinvent/services/storage_service.dart';
import 'package:nabuinvent/state/app_state.dart';

class _MemoryStorage extends StorageService {
  @override
  Future<void> save(AppData data) async {}
}

class _MemorySettings extends SettingsService {
  @override
  Future<void> save(AppSettings settings) async {}
}

/// Client lent qui respecte le signal d'interruption, comme le client réel.
class _SlowAbortableClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final slow = Future<void>.delayed(const Duration(seconds: 20));
    final abort = request is http.Abortable ? request.abortTrigger : null;
    var aborted = false;
    await Future.any([slow, if (abort != null) abort.then((_) => aborted = true)]);
    if (aborted) throw http.RequestAbortedException(request.url);
    final body = utf8.encode(jsonEncode({'choices': [{'message': {'content': '{"message":"trop tard"}'}}]}));
    return http.StreamedResponse(Stream.value(body), 200);
  }
}

void main() {
  test('« Annuler » interrompt la requête et n\'applique aucune réponse', () async {
    final client = _SlowAbortableClient();
    final app = AppState(settingsService: _MemorySettings(), storageService: _MemoryStorage());
    app.provider = OpenAICompatibleProvider(apiKey: 'k', model: 'cancel-test');

    final watch = Stopwatch()..start();
    final response = await http.runWithClient(() {
      final f = app.askAi('Invente quelque chose');
      Timer(const Duration(milliseconds: 100), app.cancelAi);
      return f;
    }, () => client);

    expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
    expect(response.message, 'Demande annulée.');
    expect(response.success, isFalse);
    expect(app.aiThinking, isFalse);
    expect(app.data.projects, isEmpty);
  });
}
