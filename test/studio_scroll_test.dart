import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nabuinvent/models/app_data.dart';
import 'package:nabuinvent/models/chat_turn.dart';
import 'package:nabuinvent/screens/studio_screen.dart';
import 'package:nabuinvent/services/settings_service.dart';
import 'package:nabuinvent/services/storage_service.dart';
import 'package:nabuinvent/state/app_state.dart';
import 'package:nabuinvent/state/tab_bus.dart';
import 'package:provider/provider.dart';

class _MemoryStorage extends StorageService {
  @override
  Future<void> save(AppData data) async {}
}

class _MemorySettings extends SettingsService {
  @override
  Future<void> save(AppSettings settings) async {}
}

/// Réponse mise en forme d'environ [length] caractères.
String _longText(int length) {
  final b = StringBuffer('# Grand plan de fabrication\n\n');
  var i = 0;
  while (b.length < length) {
    i++;
    b.writeln('## Partie $i');
    b.writeln('Texte explicatif de la partie $i, avec des **conseils** précis. ' * 4);
    b.writeln('- matériau $i\n- outil $i\n');
  }
  return b.toString();
}

Future<AppState> _pumpStudio(WidgetTester tester, List<ChatTurn> chats) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final app = AppState(settingsService: _MemorySettings(), storageService: _MemoryStorage());
  app.data = AppData(chats: chats);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<AppState>.value(value: app),
      ChangeNotifierProvider<TabBus>(create: (_) => TabBus()),
    ],
    child: const MaterialApp(home: StudioScreen()),
  ));
  await tester.pumpAndSettle();
  return app;
}

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(find.descendant(
        of: find.byKey(const Key('studio-conversation')),
        matching: find.byType(Scrollable)))
    .position;

void main() {
  for (final size in [5000, 20000, 50000]) {
    testWidgets('réponse de $size caractères : on peut remonter dans la bulle', (tester) async {
      await _pumpStudio(tester, [
        ChatTurn(role: 'user', content: 'Explique-moi tout'),
        ChatTurn(role: 'assistant', content: _longText(size), payload: {'intent': 'none'}),
      ]);

      final pos = _position(tester);
      // À l'ouverture, on est sur le dernier message.
      expect(pos.pixels, closeTo(pos.maxScrollExtent, 1));
      final bottom = pos.pixels;

      // Le doigt glisse vers le bas = on remonte dans la conversation.
      await tester.drag(find.byKey(const Key('studio-conversation')), const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(pos.pixels, lessThan(bottom - 300), reason: 'le défilement vers le haut doit fonctionner');

      // Aucun retour automatique en bas, même après un moment.
      final afterDrag = pos.pixels;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(pos.pixels, afterDrag);

      // On remonte encore, plusieurs fois de suite.
      await tester.drag(find.byKey(const Key('studio-conversation')), const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(pos.pixels, lessThan(afterDrag));

      // Le bouton « Dernier message » ramène en bas.
      expect(find.byKey(const Key('studio-latest')), findsOneWidget);
      await tester.tap(find.byKey(const Key('studio-latest')));
      await tester.pumpAndSettle();
      expect(pos.pixels, closeTo(pos.maxScrollExtent, 1));
      expect(find.byKey(const Key('studio-latest')), findsNothing);
    });
  }

  testWidgets('un nouveau message ne ramène pas en bas quelqu\'un qui relit', (tester) async {
    final app = await _pumpStudio(tester, [
      for (var i = 0; i < 12; i++) ...[
        ChatTurn(role: 'user', content: 'Question $i'),
        ChatTurn(role: 'assistant', content: _longText(1500), payload: {'intent': 'none'}),
      ],
    ]);
    final pos = _position(tester);
    await tester.drag(find.byKey(const Key('studio-conversation')), const Offset(0, 900));
    await tester.pumpAndSettle();
    final reading = pos.pixels;

    app.data = app.data.copyWith(chats: [
      ...app.data.chats,
      ChatTurn(role: 'assistant', content: 'Nouveau message', payload: {'intent': 'none'}),
    ]);
    app.notifyListeners();
    await tester.pumpAndSettle();

    expect(pos.pixels, reading);
  });

  testWidgets('une réponse JSON brute enregistrée s\'affiche en fiche lisible', (tester) async {
    final json = jsonEncode({
      'message': 'Voici un canard rustique.',
      'intent': 'invent',
      'project': {
        'title': 'Canard rustique',
        'materials': ['4 boîtes de conserve', 'fil de fer'],
        'tools': ['pince'],
        'budget': '≈ 8 €',
        'timeEstimate': '2 h',
        'difficulty': 2,
        'category': 'Jardin',
      },
    });
    await _pumpStudio(tester, [
      ChatTurn(role: 'user', content: 'Un canard en conserves'),
      // Réponse tronquée enregistrée telle quelle par une ancienne version.
      ChatTurn(role: 'assistant', content: json.substring(0, json.length - 5), payload: {'intent': 'none'}),
    ]);

    expect(find.textContaining('"materials"'), findsNothing);
    expect(find.textContaining('timeEstimate'), findsNothing);
    expect(find.text('Canard rustique'), findsOneWidget);
    expect(find.text('Matériaux'), findsOneWidget);
    expect(find.text('fil de fer'), findsOneWidget);
    expect(find.text('≈ 8 €'), findsOneWidget);
  });
}
