import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_data.dart';

class StorageService {
  static const _fileName = 'nabuinvent_data.json';

  // Les écritures passent par une file : deux sauvegardes ne peuvent jamais
  // écrire le même fichier en même temps, et la dernière demandée gagne.
  Future<void> _queue = Future.value();

  /// Dossier de données imposé (tests) ; sinon le dossier documents de l'app.
  final Directory? baseDir;

  StorageService({this.baseDir});

  Future<Directory> _appDir() async {
    final docs = baseDir ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/nabuinvent');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _dataFile() async => File('${(await _appDir()).path}/$_fileName');

  Future<File> _backupFile() async =>
      File('${(await _appDir()).path}/$_fileName.bak');

  Future<AppData> load() async {
    final file = await _dataFile();
    final main = await _tryRead(file);
    if (main != null) return main;

    // Fichier principal absent ou illisible : on tente la copie précédente.
    final backup = await _tryRead(await _backupFile());
    if (await file.exists()) {
      // On ne laisse pas la prochaine sauvegarde écraser un fichier illisible :
      // il est mis de côté pour une récupération manuelle.
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      try {
        await file.rename('${file.path}.corrompu_$stamp');
      } catch (_) {}
    }
    return backup ?? AppData();
  }

  Future<AppData?> _tryRead(File file) async {
    try {
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      return AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(AppData data) {
    // Encodage immédiat : on fige l'état au moment de l'appel.
    final content = const JsonEncoder.withIndent('  ').convert(data.toJson());
    return _enqueue(() => _writeAtomic(content));
  }

  Future<void> _enqueue(Future<void> Function() task) {
    final next = _queue.then((_) => task());
    _queue = next.catchError((_) {});
    return next;
  }

  Future<void> _writeAtomic(String content) async {
    final file = await _dataFile();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(content, flush: true);
    if (await file.exists()) {
      await file.copy((await _backupFile()).path);
    }
    // rename() remplace le fichier de façon atomique : jamais de fichier à moitié écrit.
    await tmp.rename(file.path);
  }

  Future<String> exportBackup(AppData data) async {
    final dir = await _appDir();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/nabuinvent_backup_$stamp.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data.toJson()),
      flush: true,
    );
    return file.path;
  }

  Future<AppData?> importBackup(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    final raw = await file.readAsString();
    try {
      return AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAll() => _enqueue(() async {
        for (final f in [await _dataFile(), await _backupFile()]) {
          if (await f.exists()) await f.delete();
        }
      });
}
