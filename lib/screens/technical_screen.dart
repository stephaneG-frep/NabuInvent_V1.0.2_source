import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/invention_project.dart';
import '../models/tech_sheet.dart';
import '../state/app_state.dart';
import '../tech/material_calculator.dart';
import '../tech/safety_checker.dart';
import '../tech/tech_sheet_builder.dart';
import '../widgets/common.dart';
import '../widgets/invention_sections.dart';
import '../widgets/tech_drawings.dart';

/// Concepteur technique d'un projet : fiche, pièces et calculs, plans.
class TechnicalScreen extends StatelessWidget {
  final String projectId;
  const TechnicalScreen({super.key, required this.projectId});

  static const _aiRequest =
      'Établis la fiche technique de ce projet : objectif, dimensions d\'ensemble, nomenclature des '
      'pièces cotées en millimètres avec leur position dans l\'assemblage, fixations, finitions, '
      'précautions et informations encore inconnues.';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final project = app.data.projectById(projectId);
    if (project == null) {
      return const Scaffold(body: Center(child: Text('Projet introuvable.')));
    }
    final sheet = project.tech;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(project.title, overflow: TextOverflow.ellipsis),
          actions: [
            if (sheet != null)
              IconButton(
                tooltip: 'Supprimer la fiche technique',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Supprimer la fiche technique ?'),
                      content: const Text('Une copie est conservée dans les versions du projet.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
                        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Supprimer')),
                      ],
                    ),
                  );
                  if (ok == true) app.clearTechSheet(project.id);
                },
              ),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'Fiche'),
            Tab(text: 'Pièces'),
            Tab(text: 'Plans'),
          ]),
        ),
        body: sheet == null
            ? _NoSheet(project: project, onGenerate: () => _generate(context, app, project))
            : TabBarView(children: [
                _SheetTab(project: project, sheet: sheet, onRegenerate: () => _generate(context, app, project)),
                _PartsTab(project: project, sheet: sheet),
                _PlansTab(sheet: sheet),
              ]),
      ),
    );
  }

  static Future<void> _generate(BuildContext context, AppState app, InventionProject project) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Fiche technique demandée à l\'IA…')));
    final r = await app.askAi(_aiRequest, activeProjectId: project.id);
    messenger.showSnackBar(SnackBar(
        content: Text(r.techSheet != null
            ? 'Fiche technique mise à jour. Tes mesures ont été conservées.'
            : 'L\'IA n\'a pas renvoyé de fiche technique : ${r.message}')));
  }
}

class _NoSheet extends StatelessWidget {
  final InventionProject project;
  final VoidCallback onGenerate;
  const _NoSheet({required this.project, required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const EmptyState(
          icon: Icons.architecture,
          title: 'Pas encore de fiche technique',
          subtitle: 'L\'IA propose des cotes (hypothèses à vérifier), ou pars des matériaux du projet '
              'et saisis tes propres mesures.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: app.aiThinking ? null : onGenerate,
          icon: app.aiThinking
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome),
          label: Text(app.aiThinking ? 'Génération…' : 'Proposer une fiche avec l\'IA'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => app.updateTechSheet(project.id, TechSheetBuilder.fromProject(project)),
          icon: const Icon(Icons.edit_note),
          label: const Text('Partir des matériaux (cotes à saisir)'),
        ),
      ],
    );
  }
}

/// Badge de provenance d'une donnée.
class SourceBadge extends StatelessWidget {
  final DataSource source;
  const SourceBadge(this.source, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = switch (source) {
      DataSource.user => Colors.green,
      DataSource.ai => Colors.orange,
      DataSource.computed => Colors.blue,
      DataSource.unknown => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(source.label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _ReadinessBanner extends StatelessWidget {
  final TechSheet sheet;
  const _ReadinessBanner({required this.sheet});

  @override
  Widget build(BuildContext context) {
    final r = sheet.readiness;
    final color = switch (r) {
      PlanReadiness.ready => Colors.green,
      PlanReadiness.hypothetical => Colors.orange,
      PlanReadiness.incomplete => Colors.red,
    };
    final missing = sheet.missingMeasurements;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              r == PlanReadiness.ready ? Icons.verified : Icons.report_outlined,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Text(r.label, style: TextStyle(color: color, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 4),
          Text(
            switch (r) {
              PlanReadiness.ready =>
                'Toutes les cotes viennent de tes mesures. Vérifie-les une dernière fois avant de couper.',
              PlanReadiness.hypothetical =>
                'Des cotes sont des hypothèses de l\'IA : mesure et corrige-les avant de fabriquer.',
              PlanReadiness.incomplete =>
                'Ce n\'est pas un plan de fabrication : ${missing.length} cote(s) indispensable(s) manquent.',
            },
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(missing.take(6).join(' · ') + (missing.length > 6 ? ' …' : ''),
                style: Theme.of(context).textTheme.labelSmall),
          ],
        ],
      ),
    );
  }
}

class _SheetTab extends StatelessWidget {
  final InventionProject project;
  final TechSheet sheet;
  final VoidCallback onRegenerate;
  const _SheetTab({required this.project, required this.sheet, required this.onRegenerate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.watch<AppState>();
    final budget = MaterialCalculator.budget(sheet);
    final safety = SafetyChecker.checkProject(project);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      children: [
        _ReadinessBanner(sheet: sheet),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(project.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                if (project.concept.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(project.concept, style: theme.textTheme.bodyMedium),
                ],
                if (sheet.objective.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  InfoRow(icon: Icons.flag_outlined, title: 'Objectif', value: sheet.objective),
                ],
                if (sheet.method.isNotEmpty)
                  InfoRow(icon: Icons.build_outlined, title: 'Méthode', value: sheet.method),
                const SizedBox(height: 8),
                BudgetSection(
                  budget: budget.knownTotal > 0
                      ? '${budget.knownTotal.toStringAsFixed(2).replaceAll('.', ',')} €'
                          '${budget.complete ? '' : ' + ${budget.unpricedLines} pièce(s) sans prix'}'
                      : project.budget,
                  time: project.timeEstimate,
                  difficulty: project.difficulty,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const SectionHeader('Dimensions d\'ensemble'),
        Card(
          child: Column(
            children: [
              for (final d in sheet.dimensions)
                ListTile(
                  dense: true,
                  title: Text(d.label),
                  subtitle: Text(d.value == null ? 'Inconnue' : MaterialCalculator.formatLength(d.value!)),
                  trailing: SourceBadge(d.source),
                  onTap: () async {
                    final v = await _askNumber(context, d.label, d.value);
                    if (v == null) return;
                    final next = sheet.copy();
                    next.dimensions.firstWhere((e) => e.label == d.label)
                      ..value = v
                      ..source = DataSource.user;
                    app.updateTechSheet(project.id, next);
                  },
                ),
            ],
          ),
        ),
        if (sheet.fasteners.isNotEmpty) ...[
          const SizedBox(height: 8),
          CollapsibleSection(
            title: 'Fixations',
            icon: Icons.hardware,
            child: Text(sheet.fasteners.map((e) => '• $e').join('\n')),
          ),
        ],
        if (sheet.finishes.isNotEmpty)
          CollapsibleSection(
            title: 'Finitions',
            icon: Icons.format_paint_outlined,
            child: Text(sheet.finishes.map((e) => '• $e').join('\n')),
          ),
        if (sheet.unknowns.isNotEmpty)
          CollapsibleSection(
            title: 'Encore inconnu',
            icon: Icons.help_outline,
            child: Text(sheet.unknowns.map((e) => '• $e').join('\n')),
          ),
        SafetyWarnings([...sheet.precautions, for (final f in safety) f.text]),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(SafetyChecker.disclaimer,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
        if (safety.any((f) => f.level == SafetyLevel.professional))
          Card(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Ce projet nécessite une validation professionnelle avant utilisation.'),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: app.aiThinking ? null : onRegenerate,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Compléter avec l\'IA (tes mesures sont conservées)'),
        ),
      ],
    );
  }
}

Future<double?> _askNumber(BuildContext context, String label, double? current) async {
  final c = TextEditingController(text: current == null ? '' : current.round().toString());
  final v = await showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(label),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(suffixText: 'mm', helperText: 'Ta mesure, en millimètres'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(double.tryParse(c.text.replaceAll(',', '.'))),
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
  return v != null && v > 0 ? v : null;
}

class _PartsTab extends StatelessWidget {
  final InventionProject project;
  final TechSheet sheet;
  const _PartsTab({required this.project, required this.sheet});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.read<AppState>();
    final lines = MaterialCalculator.summarize(sheet);
    final cuts = MaterialCalculator.cutPlans(sheet);
    final budget = MaterialCalculator.budget(sheet);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      children: [
        const SectionHeader('Nomenclature des pièces'),
        Text('Touche une pièce pour saisir tes mesures : elles remplacent les hypothèses.',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        for (var i = 0; i < sheet.parts.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
              title: Text('${sheet.parts[i].quantity} × ${sheet.parts[i].name}'),
              subtitle: Text(_partDims(sheet.parts[i])),
              trailing: SourceBadge(sheet.parts[i].source),
              onTap: () async {
                final edited = await showDialog<TechPart>(
                    context: context, builder: (_) => _PartDialog(part: sheet.parts[i].copy()));
                if (edited == null) return;
                final next = sheet.copy()..parts[i] = edited;
                app.updateTechSheet(project.id, next);
              },
              onLongPress: () {
                final next = sheet.copy()..parts.removeAt(i);
                app.updateTechSheet(project.id, next);
              },
            ),
          ),
        TextButton.icon(
          onPressed: () async {
            final created = await showDialog<TechPart>(
                context: context,
                builder: (_) => _PartDialog(part: TechPart(name: '', source: DataSource.user)));
            if (created == null) return;
            app.updateTechSheet(project.id, sheet.copy()..parts.add(created));
          },
          icon: const Icon(Icons.add),
          label: const Text('Ajouter une pièce'),
        ),
        const SizedBox(height: 12),
        const SectionHeader('Quantités calculées'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final l in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.material, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                        Text([
                          '${l.pieceCount} pièce(s)',
                          if (l.linearMm > 0) 'longueur ${MaterialCalculator.formatLength(l.linearMm)}',
                          if (l.areaMm2 > 0) 'surface ${MaterialCalculator.formatArea(l.areaMm2)}',
                          if (l.volumeMm3 > 0) 'volume ${(l.volumeMm3 / 1e6).toStringAsFixed(2).replaceAll('.', ',')} L',
                        ].join(' · '), style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                Text(
                  budget.knownTotal > 0
                      ? 'Budget des pièces chiffrées : ${budget.knownTotal.toStringAsFixed(2).replaceAll('.', ',')} €'
                          '${budget.complete ? '' : ' (${budget.unpricedLines} pièce(s) sans prix)'}'
                      : 'Budget : aucun prix renseigné.',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text('Valeurs calculées à partir des cotes ci-dessus — elles ne sont justes que si les cotes le sont.',
                    style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(child: SectionHeader('Plan de découpe des barres')),
            TextButton(
              onPressed: () async {
                final v = await _askNumber(context, 'Longueur des barres du commerce', sheet.stockLength);
                if (v == null) return;
                app.updateTechSheet(project.id, sheet.copy()..stockLength = v);
              },
              child: Text('Barres de ${MaterialCalculator.formatLength(sheet.stockLength)}'),
            ),
          ],
        ),
        if (cuts.isEmpty)
          Text('Aucune pièce de type barre entièrement cotée.', style: theme.textTheme.bodySmall)
        else
          for (final e in cuts.entries) _CutPlanCard(material: e.key, plan: e.value),
      ],
    );
  }

  static String _partDims(TechPart p) {
    String f(double? v) => v == null ? '?' : '${v.round()}';
    final dims = switch (p.shape) {
      PartShape.cylinder => 'Ø ${f(p.width)} × h ${f(p.length)} mm',
      PartShape.bar => 'L ${f(p.length)} mm${p.width != null ? ' · section ${f(p.width)}' : ''}',
      _ => '${f(p.length)} × ${f(p.width)} × ${f(p.thickness)} mm',
    };
    return '${p.shape.label} · $dims${p.material.isNotEmpty && p.material != p.name ? ' · ${p.material}' : ''}';
  }
}

class _CutPlanCard extends StatelessWidget {
  final String material;
  final CutPlan plan;
  const _CutPlanCard({required this.material, required this.plan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(material, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            Text(
              '${plan.barCount} barre(s) · chutes ${MaterialCalculator.formatLength(plan.totalOffcut)} · '
              'utilisation ${(plan.utilization * 100).round()} %',
              style: theme.textTheme.bodySmall,
            ),
            if (plan.tooLong.isNotEmpty)
              Text('Pièces plus longues qu\'une barre : ${plan.tooLong.map((e) => e.round()).join(', ')} mm',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            const SizedBox(height: 8),
            SizedBox(
              height: CutPlanPainter.heightFor(plan),
              width: double.infinity,
              child: CustomPaint(
                painter: CutPlanPainter(
                  plan: plan,
                  ink: theme.colorScheme.onSurface,
                  fill: theme.colorScheme.primaryContainer,
                  offcut: theme.colorScheme.surfaceContainerHighest,
                  background: theme.colorScheme.surface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartDialog extends StatefulWidget {
  final TechPart part;
  const _PartDialog({required this.part});

  @override
  State<_PartDialog> createState() => _PartDialogState();
}

class _PartDialogState extends State<_PartDialog> {
  late final TechPart p = widget.part;
  late final _name = TextEditingController(text: p.name);
  late final _material = TextEditingController(text: p.material);
  late final _qty = TextEditingController(text: '${p.quantity}');
  late final _l = TextEditingController(text: p.length?.round().toString() ?? '');
  late final _w = TextEditingController(text: p.width?.round().toString() ?? '');
  late final _t = TextEditingController(text: p.thickness?.round().toString() ?? '');
  late final _price = TextEditingController(text: p.unitPrice?.toString() ?? '');
  late PartShape _shape = p.shape;
  late PartOrientation _orientation = p.orientation;

  @override
  void dispose() {
    for (final c in [_name, _material, _qty, _l, _w, _t, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) {
    final v = double.tryParse(c.text.replaceAll(',', '.').trim());
    return v != null && v > 0 ? v : null;
  }

  @override
  Widget build(BuildContext context) {
    final cyl = _shape == PartShape.cylinder;
    return AlertDialog(
      title: Text(p.name.isEmpty ? 'Nouvelle pièce' : p.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nom')),
            const SizedBox(height: 8),
            TextField(controller: _material, decoration: const InputDecoration(labelText: 'Matériau')),
            const SizedBox(height: 8),
            DropdownButtonFormField<PartShape>(
              initialValue: _shape,
              decoration: const InputDecoration(labelText: 'Forme'),
              items: [
                for (final s in PartShape.values) DropdownMenuItem(value: s, child: Text(s.label)),
              ],
              onChanged: (v) => setState(() => _shape = v ?? _shape),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<PartOrientation>(
              initialValue: _orientation,
              decoration: const InputDecoration(labelText: 'Orientation dans l\'objet'),
              items: [
                for (final o in PartOrientation.values) DropdownMenuItem(value: o, child: Text(o.label)),
              ],
              onChanged: (v) => setState(() => _orientation = v ?? _orientation),
            ),
            const SizedBox(height: 8),
            TextField(
                controller: _qty,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantité')),
            const SizedBox(height: 8),
            TextField(
                controller: _l,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: cyl ? 'Hauteur (mm)' : 'Longueur (mm)')),
            const SizedBox(height: 8),
            TextField(
                controller: _w,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: cyl
                        ? 'Diamètre (mm)'
                        : _shape == PartShape.bar
                            ? 'Section (mm, facultatif)'
                            : 'Largeur (mm)')),
            if (_shape == PartShape.box || _shape == PartShape.sheet) ...[
              const SizedBox(height: 8),
              TextField(
                  controller: _t,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Épaisseur (mm)')),
            ],
            const SizedBox(height: 8),
            TextField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Prix unitaire (€, facultatif)')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(
          onPressed: () {
            final l = _num(_l), w = _num(_w), t = _num(_t);
            final dimsChanged = l != p.length || w != p.width || t != p.thickness;
            p
              ..name = _name.text.trim().isEmpty ? 'Pièce' : _name.text.trim()
              ..material = _material.text.trim()
              ..shape = _shape
              ..orientation = _orientation
              ..quantity = int.tryParse(_qty.text.trim()) ?? p.quantity
              ..length = l
              ..width = w
              ..thickness = t
              ..unitPrice = _num(_price);
            // Une cote saisie ou corrigée par l'utilisateur devient une mesure ;
            // une pièce sans aucune cote reste « inconnue ».
            final anyDim = l != null || w != null || t != null;
            if (!anyDim) {
              p.source = DataSource.unknown;
            } else if (dimsChanged || p.source == DataSource.unknown) {
              p.source = DataSource.user;
            }
            Navigator.of(context).pop(p);
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

class _PlansTab extends StatefulWidget {
  final TechSheet sheet;
  const _PlansTab({required this.sheet});

  @override
  State<_PlansTab> createState() => _PlansTabState();
}

class _PlansTabState extends State<_PlansTab> {
  TechView _view = TechView.front;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sheet = widget.sheet;
    final readiness = sheet.readiness;
    final drawable = projectParts(sheet.parts, TechView.front).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      children: [
        _ReadinessBanner(sheet: sheet),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          children: [
            for (final v in TechView.values)
              ChoiceChip(
                label: Text(v.label),
                selected: _view == v,
                onSelected: (_) => setState(() => _view = v),
              ),
          ],
        ),
        const SizedBox(height: 10),
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CustomPaint(
              painter: TechViewPainter(
                parts: sheet.parts,
                view: _view,
                ink: theme.colorScheme.onSurface,
                fill: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                accent: theme.colorScheme.primary,
                background: theme.colorScheme.surfaceContainerLowest,
                watermark: readiness == PlanReadiness.ready ? null : 'PLAN INDICATIF',
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$drawable / ${sheet.parts.length} pièce(s) dessinée(s). Les pièces sans cotes complètes ne '
          'sont pas dessinées. Ce schéma est calculé à partir des cotes : il ne vient pas d\'une image.',
          style: theme.textTheme.labelSmall,
        ),
        if (_view == TechView.assembly || _view == TechView.exploded) ...[
          const SizedBox(height: 10),
          const SectionHeader('Repères'),
          for (var i = 0; i < sheet.parts.length; i++)
            Text('${i + 1}. ${sheet.parts[i].quantity} × ${sheet.parts[i].name}'
                '${sheet.parts[i].fastening.isNotEmpty ? ' — ${sheet.parts[i].fastening}' : ''}'),
        ],
      ],
    );
  }
}
