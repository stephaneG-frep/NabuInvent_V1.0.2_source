import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nabuinvent/models/app_data.dart';
import 'package:nabuinvent/models/invention_project.dart';
import 'package:nabuinvent/services/storage_service.dart';

AppData _data(String title) =>
    AppData(projects: [InventionProject(id: title, title: title)]);

void main() {
  late Directory tmp;
  late StorageService storage;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('nabu_storage_');
    storage = StorageService(baseDir: tmp);
  });

  tearDown(() => tmp.delete(recursive: true));

  File dataFile() => File('${tmp.path}/nabuinvent/nabuinvent_data.json');

  test('sauvegarde puis rechargement', () async {
    await storage.save(_data('A'));
    final loaded = await storage.load();
    expect(loaded.projects.single.title, 'A');
  });

  test('des sauvegardes concurrentes gardent la dernière', () async {
    final futures = [for (var i = 0; i < 20; i++) storage.save(_data('v$i'))];
    await Future.wait(futures);
    final loaded = await storage.load();
    expect(loaded.projects.single.title, 'v19');
  });

  test('un fichier corrompu n\'est pas écrasé et la copie .bak est utilisée', () async {
    await storage.save(_data('ancien'));
    await storage.save(_data('récent'));
    await dataFile().writeAsString('{ pas du json');

    final loaded = await storage.load();

    expect(loaded.projects.single.title, 'ancien');
    final kept = tmp
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.contains('.corrompu_'));
    expect(kept, hasLength(1));
    expect(await kept.first.readAsString(), '{ pas du json');
  });

  test('la réinitialisation supprime aussi la copie .bak', () async {
    await storage.save(_data('A'));
    await storage.save(_data('B'));
    await storage.clearAll();
    final loaded = await storage.load();
    expect(loaded.projects, isEmpty);
  });
}
