import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/tech_sheet.dart';
import '../tech/material_calculator.dart';

/// Vues techniques disponibles.
enum TechView {
  front('Face'),
  side('Profil'),
  top('Dessus'),
  exploded('Éclatée'),
  assembly('Assemblage');

  const TechView(this.label);
  final String label;
}

/// Rectangle projeté d'une pièce dans une vue (coordonnées en mm).
class ProjectedPart {
  final int number;
  final TechPart part;
  final Rect rect;
  const ProjectedPart(this.number, this.part, this.rect);
}

/// Projection orthogonale déterministe des pièces cotées.
/// x = largeur (gauche→droite), y = hauteur (bas→haut), z = profondeur.
List<ProjectedPart> projectParts(List<TechPart> parts, TechView view) {
  final out = <ProjectedPart>[];
  var explodeOffset = 0.0;
  for (var i = 0; i < parts.length; i++) {
    final p = parts[i];
    if (p.missingDimensions.isNotEmpty) continue;
    final e = p.extent;
    final Rect r;
    switch (view) {
      case TechView.side:
        r = Rect.fromLTWH(p.z, p.y, e.dz, e.dy);
      case TechView.top:
        r = Rect.fromLTWH(p.x, p.z, e.dx, e.dz);
      case TechView.exploded:
        // Chaque pièce est écartée verticalement de la précédente.
        r = Rect.fromLTWH(p.x, p.y + explodeOffset, e.dx, e.dy);
        explodeOffset += math.max(40, e.dy * 0.4);
      case TechView.front:
      case TechView.assembly:
        r = Rect.fromLTWH(p.x, p.y, e.dx, e.dy);
    }
    if (r.width <= 0 || r.height <= 0) continue;
    out.add(ProjectedPart(i + 1, p, r));
  }
  return out;
}

/// Dessin d'une vue : pièces, cotes d'encombrement, repères numérotés.
class TechViewPainter extends CustomPainter {
  final List<TechPart> parts;
  final TechView view;
  final Color ink;
  final Color fill;
  final Color accent;
  final Color background;

  /// Filigrane « plan indicatif » quand des cotes sont des hypothèses.
  final String? watermark;

  TechViewPainter({
    required this.parts,
    required this.view,
    required this.ink,
    required this.fill,
    required this.accent,
    required this.background,
    this.watermark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final projected = projectParts(parts, view);
    if (projected.isEmpty) {
      _text(canvas, 'Aucune pièce entièrement cotée à dessiner.',
          Offset(size.width / 2, size.height / 2), ink, 13, center: true);
      return;
    }
    var bounds = projected.first.rect;
    for (final p in projected.skip(1)) {
      bounds = bounds.expandToInclude(p.rect);
    }
    const margin = 46.0;
    final scale = math.min(
      (size.width - margin * 2) / math.max(bounds.width, 1),
      (size.height - margin * 2) / math.max(bounds.height, 1),
    );
    // Dessin centré dans la zone disponible.
    final padX = (size.width - margin * 2 - bounds.width * scale) / 2;
    final padY = (size.height - margin * 2 - bounds.height * scale) / 2;
    // Repère « dessin » : y vers le haut pour face/profil/éclatée/assemblage.
    final flipY = view != TechView.top;
    Offset map(double x, double y) => Offset(
          margin + padX + (x - bounds.left) * scale,
          flipY
              ? size.height - margin - padY - (y - bounds.top) * scale
              : margin + padY + (y - bounds.top) * scale,
        );
    Rect mapRect(Rect r) => Rect.fromPoints(map(r.left, r.top), map(r.right, r.bottom));

    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final body = Paint()..color = fill;

    for (final p in projected) {
      final r = mapRect(p.rect);
      if (p.part.shape == PartShape.cylinder && view == TechView.top) {
        canvas.drawOval(r, body);
        canvas.drawOval(r, stroke);
      } else {
        canvas.drawRect(r, body);
        canvas.drawRect(r, stroke);
      }
      if (view == TechView.assembly || view == TechView.exploded) {
        final c = r.center;
        canvas.drawCircle(c, 10, Paint()..color = background);
        canvas.drawCircle(c, 10, Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6);
        _text(canvas, '${p.number}', c, accent, 11, center: true, bold: true);
      }
    }

    if (view == TechView.exploded) {
      final dash = Paint()
        ..color = ink.withValues(alpha: 0.35)
        ..strokeWidth = 1;
      for (final p in projected) {
        final r = mapRect(p.rect);
        for (var y = r.bottom; y < size.height - margin; y += 8) {
          canvas.drawLine(Offset(r.center.dx, y), Offset(r.center.dx, math.min(y + 4, size.height - margin)), dash);
        }
      }
    }

    // Cotes d'encombrement (largeur en bas, hauteur à gauche), sauf vue éclatée.
    if (view != TechView.exploded) {
      final dim = Paint()
        ..color = accent
        ..strokeWidth = 1;
      final bl = map(bounds.left, bounds.top);
      final br = map(bounds.right, bounds.top);
      final tl = map(bounds.left, bounds.bottom);
      final yDim = (flipY ? bl.dy : tl.dy) + (flipY ? 22 : -22);
      canvas.drawLine(Offset(bl.dx, yDim), Offset(br.dx, yDim), dim);
      for (final x in [bl.dx, br.dx]) {
        canvas.drawLine(Offset(x, yDim - 5), Offset(x, yDim + 5), dim);
      }
      _text(canvas, MaterialCalculator.formatLength(bounds.width),
          Offset((bl.dx + br.dx) / 2, yDim + (flipY ? 9 : -9)), accent, 11, center: true);
      final xDim = bl.dx - 22;
      final top = flipY ? tl.dy : bl.dy;
      final bottom = flipY ? bl.dy : tl.dy;
      canvas.drawLine(Offset(xDim, top), Offset(xDim, bottom), dim);
      for (final y in [top, bottom]) {
        canvas.drawLine(Offset(xDim - 5, y), Offset(xDim + 5, y), dim);
      }
      canvas.save();
      canvas.translate(xDim - 9, (top + bottom) / 2);
      canvas.rotate(-math.pi / 2);
      _text(canvas, MaterialCalculator.formatLength(bounds.height), Offset.zero, accent, 11,
          center: true);
      canvas.restore();
    }

    _text(canvas, 'Vue : ${view.label}', const Offset(10, 8), ink, 12, bold: true);
    if (watermark != null) {
      _text(canvas, watermark!, Offset(size.width - 10, 8), Colors.orange.shade700, 11,
          alignRight: true, bold: true);
    }
  }

  void _text(Canvas canvas, String text, Offset at, Color color, double size,
      {bool center = false, bool bold = false, bool alignRight = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color, fontSize: size, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 400);
    final dx = center
        ? at.dx - tp.width / 2
        : alignRight
            ? at.dx - tp.width
            : at.dx;
    tp.paint(canvas, Offset(dx, center ? at.dy - tp.height / 2 : at.dy));
  }

  @override
  bool shouldRepaint(covariant TechViewPainter old) => true;
}

/// Plan de découpe : une ligne par barre, morceaux cotés, chute hachurée.
class CutPlanPainter extends CustomPainter {
  final CutPlan plan;
  final Color ink;
  final Color fill;
  final Color offcut;
  final Color background;

  CutPlanPainter({
    required this.plan,
    required this.ink,
    required this.fill,
    required this.offcut,
    required this.background,
  });

  static const rowHeight = 34.0;

  static double heightFor(CutPlan plan) => 16 + plan.bars.length * (rowHeight + 10);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    const left = 8.0;
    final width = size.width - 16;
    final scale = width / plan.stockLength;
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    var y = 8.0;
    for (final bar in plan.bars) {
      var x = left;
      for (final piece in bar.pieces) {
        final r = Rect.fromLTWH(x, y, piece * scale, rowHeight);
        canvas.drawRect(r, Paint()..color = fill);
        canvas.drawRect(r, stroke);
        if (r.width > 34) {
          final tp = TextPainter(
            text: TextSpan(text: '${piece.round()}', style: TextStyle(color: ink, fontSize: 11)),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, r.center - Offset(tp.width / 2, tp.height / 2));
        }
        x += (piece + bar.kerf) * scale;
      }
      final rest = Rect.fromLTWH(x, y, math.max(0, left + width - x), rowHeight);
      if (rest.width > 0) {
        canvas.drawRect(rest, Paint()..color = offcut);
        canvas.drawRect(rest, stroke);
      }
      y += rowHeight + 10;
    }
  }

  @override
  bool shouldRepaint(covariant CutPlanPainter old) => true;
}
