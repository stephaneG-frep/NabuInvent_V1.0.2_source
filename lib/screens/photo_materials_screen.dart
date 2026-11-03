import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../ai/ai_provider.dart';
import '../models/material_analysis.dart';
import '../state/app_state.dart';
import '../state/tab_bus.dart';
import '../widgets/common.dart';

/// « Qu'est-ce que je peux fabriquer avec ça ? » : photo → objets reconnus par
/// un vrai modèle multimodal → correction par l'utilisateur → idées.
class PhotoMaterialsScreen extends StatefulWidget {
  const PhotoMaterialsScreen({super.key});

  @override
  State<PhotoMaterialsScreen> createState() => _PhotoMaterialsScreenState();
}

class _PhotoMaterialsScreenState extends State<PhotoMaterialsScreen> {
  final _picker = ImagePicker();
  final _note = TextEditingController();
  Uint8List? _image;
  String _mime = 'image/jpeg';
  bool _loading = false;
  String? _error;
  MaterialAnalysis? _analysis;
  List<DetectedMaterial> _items = [];

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      // Image réduite et recompressée sur l'appareil : moins de données envoyées.
      final file = await _picker.pickImage(
          source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _image = bytes;
        _mime = file.mimeType ?? 'image/jpeg';
        _analysis = null;
        _items = [];
        _error = null;
      });
    } catch (e) {
      setState(() => _error = source == ImageSource.camera
          ? 'Impossible d\'ouvrir l\'appareil photo : ${friendlyAiError(e)}'
          : 'Impossible d\'ouvrir la galerie : ${friendlyAiError(e)}');
    }
  }

  Future<bool> _askConsent(AppState app) async {
    if (app.photoConsentGiven) return true;
    var remember = false;
    final host = Uri.tryParse(app.settings.aiBaseUrl.trim())?.host ?? app.settings.aiBaseUrl;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Envoyer la photo ?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('La photo sera envoyée à ton fournisseur IA ($host) pour être analysée. '
                  'Elle est soumise à ses conditions d\'utilisation. NabuInvent ne la '
                  'conserve pas après l\'analyse.\n\nÉvite les photos montrant des personnes '
                  'ou des informations privées.'),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: remember,
                onChanged: (v) => setLocal(() => remember = v ?? false),
                title: const Text('Ne plus demander pour ce fournisseur'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Envoyer')),
          ],
        ),
      ),
    );
    if (ok == true && remember) await app.rememberPhotoConsent();
    return ok == true;
  }

  Future<void> _analyze() async {
    final app = context.read<AppState>();
    final vision = app.vision;
    final image = _image;
    if (vision == null || image == null) return;
    if (!await _askConsent(app)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final analysis = await vision.analyzeMaterials(
          imageBytes: image, mimeType: _mime, note: _note.text);
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _items = List.of(analysis.items);
      });
    } catch (e) {
      if (!mounted) return;
      final msg = friendlyAiError(e);
      setState(() => _error = RegExp(r'image|vision|multimodal', caseSensitive: false).hasMatch(msg)
          ? 'Ce modèle ne semble pas accepter les images. Choisis un modèle multimodal '
              '(ex. Claude, GPT-4o, Gemini) dans les Réglages.\n\n$msg'
          : msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _propose() {
    final items = _items.where((i) => i.name.trim().isNotEmpty).toList();
    if (items.isEmpty) return;
    final request = MaterialAnalysis.toResourceRequest(items);
    Navigator.of(context).popUntil((route) => route.isFirst);
    context.read<TabBus>().go(2);
    context.read<AppState>().askAi(request);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);
    final available = app.vision != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Fabriquer avec ça ?')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          if (!available)
            Card(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.cloud_off),
                      const SizedBox(width: 8),
                      Text('Fonction non disponible',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 8),
                    const Text(
                        'L\'analyse de photo demande le mode cloud avec un modèle capable de '
                        'lire les images (Claude, GPT-4o, Gemini…). Le mode local ne peut pas '
                        'analyser une photo et ne fera pas semblant.'),
                    const SizedBox(height: 10),
                    FilledButton.tonal(
                      onPressed: () {
                        Navigator.of(context).popUntil((r) => r.isFirst);
                        context.read<TabBus>().go(4);
                      },
                      child: const Text('Ouvrir les Réglages'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          const SectionHeader('1. Ta photo'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_image != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(_image!, height: 220, fit: BoxFit.cover),
                    )
                  else
                    Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                          child: Text('Photographie tes matériaux bien éclairés, à plat.')),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _loading ? null : () => _pick(ImageSource.camera),
                          icon: const Icon(Icons.photo_camera),
                          label: const Text('Appareil photo'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : () => _pick(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Galerie'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _note,
                    decoration: const InputDecoration(
                        hintText: 'Précision facultative (ex. : boîtes de 400 g)'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: !available || _image == null || _loading ? null : _analyze,
                    icon: _loading
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.search),
                    label: Text(_loading ? 'Analyse en cours…' : 'Analyser la photo'),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null)
            Card(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: SelectableText(_error!),
              ),
            ),
          if (_analysis != null) ...[
            const SizedBox(height: 14),
            const SectionHeader('2. Ce que l\'IA reconnaît'),
            const SizedBox(height: 4),
            if (_analysis!.message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_analysis!.message, style: theme.textTheme.bodyMedium),
              ),
            Text('Corrige, complète et ajoute les dimensions : l\'IA ne mesure pas sur une photo.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            for (final item in _items)
              _ItemEditor(
                key: ObjectKey(item),
                item: item,
                onDelete: () => setState(() => _items.remove(item)),
              ),
            TextButton.icon(
              onPressed: () => setState(
                  () => _items.add(DetectedMaterial(name: '', edited: true))),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un élément'),
            ),
            if (_analysis!.questions.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Informations utiles à préciser',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      for (final q in _analysis!.questions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $q', style: theme.textTheme.bodySmall),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 14),
            const SectionHeader('3. Des idées de création'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _items.any((i) => i.name.trim().isNotEmpty) ? _propose : null,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Proposer des créations'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemEditor extends StatefulWidget {
  final DetectedMaterial item;
  final VoidCallback onDelete;
  const _ItemEditor({super.key, required this.item, required this.onDelete});

  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  late final _name = TextEditingController(text: widget.item.name);
  late final _qty = TextEditingController(text: widget.item.quantity?.toString() ?? '');
  late final _dims = TextEditingController(text: widget.item.dimensions);

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _dims.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _name,
                    decoration: InputDecoration(
                      labelText: 'Objet ou matériau',
                      helperText: item.material.isNotEmpty ? item.material : null,
                    ),
                    onChanged: (v) {
                      item.name = v;
                      item.edited = true;
                    },
                  ),
                ),
                if (!item.edited && item.confidence > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('${item.confidence} %',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: item.confidence >= 70
                                ? Colors.green
                                : theme.colorScheme.onSurfaceVariant)),
                  ),
                IconButton(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Retirer',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _qty,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantité'),
                    onChanged: (v) {
                      item.quantity = int.tryParse(v.trim());
                      item.edited = true;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _dims,
                    decoration: const InputDecoration(
                        labelText: 'Dimensions', hintText: 'ex. Ø 7 × 11 cm'),
                    onChanged: (v) {
                      item.dimensions = v;
                      item.edited = true;
                    },
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
