import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'guide_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _baseUrl = TextEditingController();
  final _apiKey = TextEditingController();
  final _model = TextEditingController();
  bool _testing = false;

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    _model.dispose();
    super.dispose();
  }

  void _syncControllers(AppState app) {
    if (_baseUrl.text != app.settings.aiBaseUrl) {
      _baseUrl.text = app.settings.aiBaseUrl;
    }
    if (_apiKey.text != app.settings.apiKey) {
      _apiKey.text = app.settings.apiKey;
    }
    if (_model.text != app.settings.aiModel) {
      _model.text = app.settings.aiModel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    _syncControllers(app);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Réglages'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          const SectionHeader('Assistant IA'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        avatar: const Icon(Icons.offline_bolt_outlined, size: 17),
                        label: const Text('Mode local'),
                        selected: !app.settings.useCloud,
                        onSelected: (_) => app.updateSettings(
                          app.settings.copyWith(aiProvider: 'local'),
                        ),
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.cloud_outlined, size: 17),
                        label: const Text('Mode cloud'),
                        selected: app.settings.useCloud,
                        onSelected: (_) => app.updateSettings(
                          app.settings.copyWith(aiProvider: 'openai'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    app.settings.useCloud
                        ? 'Connecte-toi à n\'importe quelle API compatible OpenAI '
                            '(OpenAI, OpenRouter, Mistral, Groq, Perplexity, Claude, '
                            'Gemini…) pour des inventions plus riches.'
                        : 'Atelier local : fonctionne 100 % hors ligne. Idéal pour '
                            'démarrer, mais moins inventif qu\'un grand modèle.',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant, height: 1.4),
                  ),
                  if (app.settings.useCloud) ...[
                    const SizedBox(height: 14),
                    const Text('Fournisseurs prédéfinis',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final p in _presets)
                          ActionChip(
                            avatar: const Icon(Icons.storage, size: 15),
                            label: Text(p.name),
                            onPressed: () => _applyPreset(app, p),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _baseUrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'URL de base',
                        hintText: 'https://api.openai.com/v1',
                      ),
                      onChanged: (v) =>
                          app.updateSettings(app.settings.copyWith(aiBaseUrl: v)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _apiKey,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Clé API',
                        helperText: 'Stockée localement sur l\'appareil.',
                      ),
                      onChanged: (v) =>
                          app.updateSettings(app.settings.copyWith(apiKey: v)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _model,
                      decoration: const InputDecoration(
                        labelText: 'Modèle',
                        hintText: 'gpt-4o-mini',
                      ),
                      onChanged: (v) =>
                          app.updateSettings(app.settings.copyWith(aiModel: v)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _testing ? null : () => _testConnection(app),
                          icon: _testing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.wifi_tethering),
                          label: const Text('Tester la connexion'),
                        ),
                        const Spacer(),
                        if (app.provider.isConfigured)
                          Text('Configurée ✓',
                              style: TextStyle(
                                  color: Colors.green, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const SectionHeader('Apparence'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        avatar: const Icon(Icons.brightness_auto, size: 17),
                        label: const Text('Système'),
                        selected: app.settings.themeMode == ThemeMode.system,
                        onSelected: (_) => app.updateSettings(
                          app.settings.copyWith(themeMode: ThemeMode.system),
                        ),
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.light_mode, size: 17),
                        label: const Text('Clair'),
                        selected: app.settings.themeMode == ThemeMode.light,
                        onSelected: (_) => app.updateSettings(
                          app.settings.copyWith(themeMode: ThemeMode.light),
                        ),
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.dark_mode, size: 17),
                        label: const Text('Sombre'),
                        selected: app.settings.themeMode == ThemeMode.dark,
                        onSelected: (_) => app.updateSettings(
                          app.settings.copyWith(themeMode: ThemeMode.dark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Couleur d\'accent',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (var i = 0; i < AppThemes.accentSeeds.length; i++)
                        GestureDetector(
                          onTap: () => app.updateSettings(
                            app.settings.copyWith(accentIndex: i),
                          ),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppThemes.accentSeeds[i],
                              border: Border.all(
                                width: 3,
                                color: app.settings.accentIndex == i
                                    ? theme.colorScheme.onSurface
                                    : Colors.transparent,
                              ),
                            ),
                            child: app.settings.accentIndex == i
                                ? const Icon(Icons.check, size: 18, color: Colors.white)
                                : null,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const SectionHeader('Aide'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text('Mode d\'emploi'),
                  subtitle: const Text('Découvrir NabuInvent pas à pas'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const GuideScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionHeader('Données'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('Exporter une sauvegarde'),
                  subtitle: const Text('JSON complet de tes projets'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _export(app),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Importer une sauvegarde'),
                  subtitle: const Text('Restaure un fichier JSON'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _import(app),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                  title: const Text('Tout réinitialiser',
                      style: TextStyle(color: Colors.redAccent)),
                  subtitle: const Text('Efface projets, journal, carnet et étincelles'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _reset(app),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionHeader('À propos'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.lightbulb,
                            color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('NabuInvent AI',
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            Text('Version 1.0.2',
                                style: theme.textTheme.labelSmall),
                          ],
                        ),
                      ),
                      const IconButton(
                        onPressed: null,
                        icon: Icon(Icons.more_horiz),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'L\'agent IA inventeur, bricoleur et créatif. Génère des inventions, '
                    'élabore des plans de construction, évalue les idées et nourrit '
                    'ta créativité. NabuInvent AI fonctionne entièrement en mode local '
                    'ou se connecte à ton API OpenAI préférée.',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _presets = [
    _Preset('OpenAI', 'https://api.openai.com/v1', 'gpt-4o-mini'),
    _Preset('OpenRouter', 'https://openrouter.ai/api/v1', 'openai/gpt-4o-mini'),
    _Preset('Mistral', 'https://api.mistral.ai/v1', 'mistral-small-latest'),
    _Preset('Groq', 'https://api.groq.com/openai/v1', 'llama-3.3-70b-versatile'),
    _Preset('Perplexity', 'https://api.perplexity.ai', 'sonar'),
    _Preset('Anthropic (Claude)',
        'https://api.anthropic.com/v1', 'claude-sonnet-5-5'),
    _Preset('Google (Gemini)',
        'https://generativelanguage.googleapis.com/v1beta/openai',
        'gemini-2.5-flash'),
  ];

  void _applyPreset(AppState app, _Preset preset) {
    app.updateSettings(app.settings.copyWith(
      aiBaseUrl: preset.baseUrl,
      aiModel: preset.model,
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Préréglage ${preset.name} appliqué. Colle ta clé API.')),
    );
  }

  Future<void> _testConnection(AppState app) async {
    setState(() => _testing = true);
    final error = await app.testConnection();
    if (!mounted) return;
    setState(() => _testing = false);
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connexion réussie — l\'IA répond !'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }
    // Un dialogue plutôt qu'un snackbar : le message du fournisseur peut être
    // long et l'utilisateur doit pouvoir le lire (et le copier).
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Échec de la connexion'),
        content: SelectableText(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _export(AppState app) async {
    try {
      final path = await app.exportBackup();
      await SharePlus.instance.share(
        ShareParams(
          text: 'Sauvegarde NabuInvent AI',
          files: [XFile(path, mimeType: 'application/json')],
        ),
      );
    } catch (e) {
      _toast('Export impossible : $e');
    }
  }

  Future<void> _import(AppState app) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      final file = files.isEmpty ? null : files.first;
      if (file == null) return;
      final path = file.path;
      if (path == null) return;
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Importer la sauvegarde ?'),
          content: const Text(
              'Les données actuelles seront remplacées par le contenu du fichier.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Importer'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final imported = await app.importBackup(path);
      _toast(imported == null
          ? 'Fichier invalide ou illisible.'
          : 'Sauvegarde importée : ${imported.projects.length} projets.');
    } catch (e) {
      _toast('Import impossible : $e');
    }
  }

  Future<void> _reset(AppState app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tout réinitialiser ?'),
        content: const Text('Tous tes projets, notes, idées et étincelles seront effacés. '
            'Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await app.resetAll();
      _toast('Toutes les données ont été réinitialisées.');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _Preset {
  final String name;
  final String baseUrl;
  final String model;
  const _Preset(this.name, this.baseUrl, this.model);
}