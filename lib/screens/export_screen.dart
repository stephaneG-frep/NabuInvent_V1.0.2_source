import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../export/project_exporter.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Export d'un projet : PDF, ZIP, JSON et schémas PNG. « Enregistrer » ouvre
/// le sélecteur de destination du système (aucune permission de stockage).
class ExportScreen extends StatefulWidget {
  final String projectId;
  const ExportScreen({super.key, required this.projectId});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  Future<ProjectExport>? _export;
  ProjectExport? _zipFor;
  Uint8List? _zip;

  void _build() {
    final p = context.read<AppState>().data.projectById(widget.projectId);
    if (p == null) return;
    setState(() => _export = ProjectExporter.build(p));
  }

  Future<void> _save(String fileName, Uint8List bytes, String mime) async {
    try {
      final uri = await FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: mime);
      if (!mounted || uri == null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('« $fileName » enregistré.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enregistrement impossible : $e')));
      }
    }
  }

  Future<void> _share(String fileName, Uint8List bytes, String mime) async {
    try {
      final dir = await context.read<AppState>().storageService.exportDir();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: mime)]));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Partage impossible : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.data.projectById(widget.projectId);
    if (p == null) return const Scaffold(body: Center(child: Text('Projet introuvable.')));
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Exporter le projet')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          Text(p.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Le dossier rassemble la fiche, la nomenclature, les calculs, les étapes, la sécurité, '
              'les schémas calculés et les aperçus générés. Tout est produit sur l\'appareil, hors ligne.',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 14),
          if (_export == null)
            FilledButton.icon(
              onPressed: _build,
              icon: const Icon(Icons.inventory_outlined),
              label: const Text('Préparer le dossier'),
            )
          else
            FutureBuilder<ProjectExport>(
              future: _export,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Card(
                    color: theme.colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Préparation impossible : ${snap.error}'),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final e = snap.data!;
                if (!identical(_zipFor, e)) {
                  _zipFor = e;
                  _zip = ProjectExporter.zip(e, p);
                }
                final zip = _zip!;
                final items = <(IconData, String, String, Uint8List, String)>[
                  (Icons.picture_as_pdf_outlined, 'Dossier PDF', '${e.baseName}.pdf', e.pdf, 'application/pdf'),
                  (Icons.folder_zip_outlined, 'Archive ZIP complète', '${e.baseName}.zip', zip, 'application/zip'),
                  (Icons.data_object, 'Données JSON', '${e.baseName}.json', e.json, 'application/json'),
                  for (final s in e.schematics.entries)
                    (Icons.architecture, 'Schéma — ${ProjectExporter.schematicLabel(s.key)}',
                        '${e.baseName}_${s.key}', s.value, 'image/png'),
                ];
                return Column(
                  children: [
                    for (final (icon, label, name, bytes, mime) in items)
                      Card(
                        child: ListTile(
                          leading: Icon(icon),
                          title: Text(label),
                          subtitle: Text('${(bytes.length / 1024).ceil()} Ko'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Enregistrer',
                                icon: const Icon(Icons.save_alt),
                                onPressed: () => _save(name, bytes, mime),
                              ),
                              IconButton(
                                tooltip: 'Partager',
                                icon: const Icon(Icons.share_outlined),
                                onPressed: () => _share(name, bytes, mime),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (e.schematics.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: EmptyState(
                          icon: Icons.architecture,
                          title: 'Pas de schéma',
                          subtitle: 'Ajoute des pièces cotées dans la conception technique pour obtenir les plans PNG.',
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
