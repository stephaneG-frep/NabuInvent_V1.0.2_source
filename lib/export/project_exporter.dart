import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/invention_project.dart';
import '../models/tech_sheet.dart';
import '../tech/material_calculator.dart';
import '../tech/safety_checker.dart';
import '../widgets/tech_drawings.dart';
import 'project_text.dart';

/// Fichiers d'un dossier de projet exporté.
class ProjectExport {
  final String baseName;
  final Uint8List json;
  final Uint8List pdf;

  /// Schémas PNG : nom de fichier → contenu.
  final Map<String, Uint8List> schematics;

  /// Aperçus générés : nom de fichier → contenu.
  final Map<String, Uint8List> images;

  const ProjectExport({
    required this.baseName,
    required this.json,
    required this.pdf,
    required this.schematics,
    required this.images,
  });
}

/// Exports réels d'un projet : PDF, PNG, JSON et ZIP.
class ProjectExporter {
  ProjectExporter._();

  /// Nom de fichier sûr, sans accents ni caractères spéciaux.
  static String safeName(String title) {
    const from = 'àáâäãåçèéêëìíîïòóôöõùúûüýÿñœ';
    const to = 'aaaaaaceeeeiiiiooooouuuuyyno';
    final b = StringBuffer();
    for (final ch in title.toLowerCase().split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    final s = b.toString().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    return s.isEmpty ? 'projet' : (s.length > 40 ? s.substring(0, 40) : s);
  }

  /// JSON structuré : le projet complet + les calculs et contrôles dérivés.
  static Map<String, dynamic> projectJson(InventionProject p) {
    final tech = p.tech;
    return {
      'format': 'nabuinvent-projet',
      'formatVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'project': p.toJson(),
      if (tech != null)
        'calculs': {
          'etatDuPlan': tech.readiness.label,
          'mesuresManquantes': tech.missingMeasurements,
          'materiaux': [
            for (final l in MaterialCalculator.summarize(tech))
              {
                'materiau': l.material,
                'pieces': l.pieceCount,
                'longueurMm': l.linearMm,
                'surfaceMm2': l.areaMm2,
                'volumeMm3': l.volumeMm3,
              }
          ],
          'decoupe': {
            for (final e in MaterialCalculator.cutPlans(tech).entries)
              e.key: {
                'barres': e.value.barCount,
                'longueurBarreMm': e.value.stockLength,
                'chutesMm': e.value.totalOffcut,
                'trop_longues': e.value.tooLong,
                'detail': [for (final b in e.value.bars) b.pieces],
              }
          },
          'budget': {
            'totalConnuEuros': MaterialCalculator.budget(tech).knownTotal,
            'piecesSansPrix': MaterialCalculator.budget(tech).unpricedLines,
          },
        },
      'securite': [for (final f in SafetyChecker.checkProject(p)) {'niveau': f.level.label, 'texte': f.text}],
    };
  }

  /// Rend une vue technique en PNG (fond blanc, encre sombre), sans écran.
  static Future<Uint8List> renderViewPng(TechSheet sheet, TechView view, {double size = 1200}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    TechViewPainter(
      parts: sheet.parts,
      view: view,
      ink: const Color(0xFF222222),
      fill: const Color(0xFFF3E3CC),
      accent: const Color(0xFF9A5B1E),
      background: Colors.white,
      watermark: sheet.readiness == PlanReadiness.ready ? null : 'PLAN INDICATIF',
    ).paint(canvas, Size(size, size));
    final image = await recorder.endRecording().toImage(size.round(), size.round());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  static Future<Uint8List> renderCutPlanPng(CutPlan plan, {double width = 1400}) async {
    final height = CutPlanPainter.heightFor(plan);
    final recorder = ui.PictureRecorder();
    CutPlanPainter(
      plan: plan,
      ink: const Color(0xFF222222),
      fill: const Color(0xFFF3E3CC),
      offcut: const Color(0xFFDDDDDD),
      background: Colors.white,
    ).paint(Canvas(recorder), Size(width, height));
    final image = await recorder.endRecording().toImage(width.round(), height.round());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  /// Libellé lisible d'un fichier de schéma (« vue_eclatee.png » → « Vue Éclatée »).
  static String schematicLabel(String fileName) {
    for (final v in TechView.values) {
      if (fileName == 'vue_${safeName(v.label)}.png') return 'Vue ${v.label.toLowerCase()}';
    }
    return fileName.replaceAll('.png', '').replaceAll('_', ' ');
  }

  /// Tous les schémas disponibles (vues + plans de découpe).
  static Future<Map<String, Uint8List>> schematics(InventionProject p) async {
    final tech = p.tech;
    if (tech == null || projectParts(tech.parts, TechView.front).isEmpty) {
      return {};
    }
    final out = <String, Uint8List>{};
    for (final v in TechView.values) {
      out['vue_${safeName(v.label)}.png'] = await renderViewPng(tech, v);
    }
    for (final e in MaterialCalculator.cutPlans(tech).entries) {
      out['decoupe_${safeName(e.key)}.png'] = await renderCutPlanPng(e.value);
    }
    return out;
  }

  static Future<pw.ThemeData> _theme() async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));
    return pw.ThemeData.withFont(base: regular, bold: bold);
  }

  /// Dossier PDF du projet.
  static Future<Uint8List> buildPdf(
    InventionProject p, {
    Map<String, Uint8List> schematics = const {},
    Map<String, Uint8List> images = const {},
  }) async {
    final doc = pw.Document(theme: await _theme(), title: p.title, author: 'NabuInvent AI');
    const copper = PdfColor.fromInt(0xFF9A5B1E);
    final tech = p.tech;
    final safety = SafetyChecker.checkProject(p);

    pw.Widget h(String text) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
          child: pw.Text(text, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: copper)),
        );
    pw.Widget bullets(List<String> items) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [for (final i in items) pw.Bullet(text: i)],
        );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('NabuInvent AI · ${p.title} · page ${ctx.pageNumber}/${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ),
      build: (ctx) => [
        pw.Text(p.title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.Text('Dossier exporté le ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        if (images.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          pw.Center(child: pw.Image(pw.MemoryImage(images.values.last), height: 220)),
          pw.Text('Aperçu artistique généré par IA — ne sert pas de plan de fabrication.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        ],
        if (p.problem.isNotEmpty) ...[h('Objectif'), pw.Text(p.problem)],
        if (p.concept.isNotEmpty) ...[h('Concept'), pw.Text(p.concept)],
        if (p.mechanism.isNotEmpty) ...[h('Principe'), pw.Text(p.mechanism)],
        h('Repères'),
        bullets([
          if (p.budget.isNotEmpty) 'Budget estimé : ${p.budget}',
          if (p.timeEstimate.isNotEmpty) 'Durée : ${p.timeEstimate}',
          'Difficulté : ${p.difficulty}/5',
        ]),
        if (p.materials.isNotEmpty) ...[h('Matériaux'), bullets(p.materials)],
        if (p.tools.isNotEmpty) ...[h('Outils'), bullets(p.tools)],
        if (p.designNotes.isNotEmpty) ...[h('Contraintes et décisions'), bullets(p.designNotes)],
        if (tech != null) ...[
          h('Fiche technique — ${tech.readiness.label}'),
          if (tech.missingMeasurements.isNotEmpty)
            pw.Text('Mesures manquantes : ${tech.missingMeasurements.join(' ; ')}',
                style: const pw.TextStyle(color: PdfColors.red800, fontSize: 9)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headers: ['N°', 'Pièce', 'Qté', 'Forme', 'L', 'l / Ø', 'ép.', 'Origine'],
            data: [
              for (var i = 0; i < tech.parts.length; i++)
                [
                  '${i + 1}',
                  tech.parts[i].name,
                  '${tech.parts[i].quantity}',
                  tech.parts[i].shape.label,
                  tech.parts[i].length?.round().toString() ?? '?',
                  tech.parts[i].width?.round().toString() ?? '?',
                  tech.parts[i].thickness?.round().toString() ?? '—',
                  tech.parts[i].source.label,
                ]
            ],
          ),
          pw.Text('Cotes en millimètres.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          if (tech.fasteners.isNotEmpty) ...[h('Fixations'), bullets(tech.fasteners)],
          if (tech.finishes.isNotEmpty) ...[h('Finitions'), bullets(tech.finishes)],
          h('Calculs'),
          bullets([
            for (final l in MaterialCalculator.summarize(tech))
              '${l.material} : ${l.pieceCount} pièce(s)'
                  '${l.linearMm > 0 ? ', ${MaterialCalculator.formatLength(l.linearMm)}' : ''}'
                  '${l.areaMm2 > 0 ? ', ${MaterialCalculator.formatArea(l.areaMm2)}' : ''}',
            for (final e in MaterialCalculator.cutPlans(tech).entries)
              'Découpe ${e.key} : ${e.value.barCount} barre(s) de '
                  '${MaterialCalculator.formatLength(e.value.stockLength)}, chutes '
                  '${MaterialCalculator.formatLength(e.value.totalOffcut)}',
          ]),
        ],
        if (p.plan.steps.isNotEmpty) ...[
          h('Étapes de fabrication'),
          for (var i = 0; i < p.plan.steps.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('${i + 1}. ${p.plan.steps[i].title}'
                      '${p.plan.steps[i].done ? '  ✓' : ''}'
                      '${p.plan.steps[i].duration.isNotEmpty ? '  (${p.plan.steps[i].duration})' : ''}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  if (p.plan.steps[i].detail.isNotEmpty) pw.Text(p.plan.steps[i].detail),
                  if (p.plan.steps[i].safety.isNotEmpty)
                    pw.Text('Précaution : ${p.plan.steps[i].safety}',
                        style: const pw.TextStyle(color: PdfColors.orange800)),
                ],
              ),
            ),
        ],
        if (safety.isNotEmpty) ...[
          h('Sécurité'),
          bullets([for (final f in safety) '[${f.level.label}] ${f.text}']),
          pw.Text(SafetyChecker.disclaimer, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        ],
        if (p.versions.isNotEmpty) ...[
          h('Historique des versions'),
          bullets([
            for (final v in p.versions)
              '${DateFormat('dd/MM/yyyy HH:mm').format(v.createdAt)} — ${v.reason}'
          ]),
        ],
      ],
    ));

    for (final e in schematics.entries) {
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Column(
          children: [
            pw.Text(e.key.replaceAll('_', ' ').replaceAll('.png', ''),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Expanded(child: pw.Image(pw.MemoryImage(e.value), fit: pw.BoxFit.contain)),
          ],
        ),
      ));
    }
    return doc.save();
  }

  /// Rassemble tous les fichiers d'un projet.
  static Future<ProjectExport> build(InventionProject p) async {
    final schemas = await schematics(p);
    final images = <String, Uint8List>{};
    for (var i = 0; i < p.visuals.length; i++) {
      final f = File(p.visuals[i].filePath);
      if (await f.exists()) {
        images['apercu_${i + 1}_${safeName(p.visuals[i].style)}.png'] = await f.readAsBytes();
      }
    }
    final json = Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(projectJson(p))));
    final pdf = await buildPdf(p, schematics: schemas, images: images);
    return ProjectExport(
      baseName: safeName(p.title),
      json: json,
      pdf: pdf,
      schematics: schemas,
      images: images,
    );
  }

  /// Archive ZIP contenant tous les fichiers disponibles du projet.
  static Uint8List zip(ProjectExport e, InventionProject p) {
    final archive = Archive();
    void add(String name, List<int> bytes) => archive.addFile(ArchiveFile(name, bytes.length, bytes));
    add('${e.baseName}/projet.json', e.json);
    add('${e.baseName}/dossier.pdf', e.pdf);
    add('${e.baseName}/fiche.txt', utf8.encode(projectToPlainText(p)));
    for (final s in e.schematics.entries) {
      add('${e.baseName}/plans/${s.key}', s.value);
    }
    for (final i in e.images.entries) {
      add('${e.baseName}/apercus/${i.key}', i.value);
    }
    add('${e.baseName}/LISEZMOI.txt', utf8.encode(
        'Dossier NabuInvent AI : ${p.title}\n\n'
        'projet.json : données complètes (réimportables)\n'
        'dossier.pdf : fiche, nomenclature, calculs, étapes, sécurité, schémas\n'
        'plans/ : schémas techniques PNG calculés à partir des cotes\n'
        'apercus/ : aperçus artistiques générés par IA (ne servent pas de plan)\n'));
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }
}
