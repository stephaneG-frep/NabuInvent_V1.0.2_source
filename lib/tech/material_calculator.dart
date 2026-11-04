import 'dart:math' as math;

import '../models/tech_sheet.dart';

/// Une barre du commerce et les morceaux qu'on y découpe.
class StockBar {
  final List<double> pieces;
  final double stockLength;
  final double kerf;

  const StockBar(this.pieces, this.stockLength, this.kerf);

  /// Longueur consommée : morceaux + un trait de scie par coupe.
  double get used => pieces.fold(0.0, (a, b) => a + b) + kerf * pieces.length;

  double get offcut => math.max(0, stockLength - used);
}

/// Plan de découpe de pièces linéaires dans des barres de longueur fixe.
class CutPlan {
  final List<StockBar> bars;

  /// Pièces impossibles à tirer d'une barre (plus longues que la barre).
  final List<double> tooLong;
  final double stockLength;

  const CutPlan(this.bars, this.tooLong, this.stockLength);

  int get barCount => bars.length;

  double get totalPieces => bars.fold(0.0, (a, b) => a + b.pieces.fold(0.0, (x, y) => x + y));

  double get totalOffcut => bars.fold(0.0, (a, b) => a + b.offcut);

  /// Part de la matière achetée qui finit en pièces (0–1).
  double get utilization => bars.isEmpty ? 0 : totalPieces / (bars.length * stockLength);
}

/// Surfaces et quantités d'un matériau.
class MaterialLine {
  final String material;
  final int pieceCount;

  /// Longueur cumulée des barres (mm), 0 si non concerné.
  final double linearMm;

  /// Surface cumulée des feuilles et faces de pavés (mm²).
  final double areaMm2;

  /// Volume cumulé (mm³).
  final double volumeMm3;

  const MaterialLine({
    required this.material,
    required this.pieceCount,
    this.linearMm = 0,
    this.areaMm2 = 0,
    this.volumeMm3 = 0,
  });
}

/// Budget : total des prix connus et nombre de pièces sans prix.
class BudgetEstimate {
  final double knownTotal;
  final int unpricedLines;

  const BudgetEstimate(this.knownTotal, this.unpricedLines);

  bool get complete => unpricedLines == 0;
}

/// Calculs techniques déterministes et testables. Le modèle IA ne fournit que
/// des hypothèses de cotes ; quantités, longueurs, surfaces, chutes et budget
/// sont toujours recalculés ici.
class MaterialCalculator {
  MaterialCalculator._();

  /// Plan de découpe « premier ajustement décroissant » : chaque morceau,
  /// du plus long au plus court, va dans la première barre où il tient.
  static CutPlan planLinearCuts(
    List<double> pieces, {
    required double stockLength,
    double kerf = 3,
  }) {
    assert(stockLength > 0);
    final sorted = [...pieces.where((p) => p > 0)]..sort((a, b) => b.compareTo(a));
    final bars = <List<double>>[];
    final tooLong = <double>[];
    for (final piece in sorted) {
      if (piece > stockLength + 1e-9) {
        tooLong.add(piece);
        continue;
      }
      var placed = false;
      for (final bar in bars) {
        final used = bar.fold(0.0, (a, b) => a + b) + kerf * bar.length;
        // La dernière coupe d'une barre peut se passer de trait de scie.
        if (used + piece <= stockLength + 1e-9) {
          bar.add(piece);
          placed = true;
          break;
        }
      }
      if (!placed) bars.add([piece]);
    }
    return CutPlan(
      [for (final b in bars) StockBar(b, stockLength, kerf)],
      tooLong,
      stockLength,
    );
  }

  static double rectangleArea(double length, double width) => length * width;

  static double boxVolume(double length, double width, double thickness) =>
      length * width * thickness;

  /// Surface latérale d'un cylindre (une boîte de conserve ouverte et aplatie).
  static double cylinderLateralArea(double diameter, double height) => math.pi * diameter * height;

  /// Nombre de boîtes à aplatir pour obtenir [areaMm2] de tôle, avec une part
  /// utilisable (bords, sertissage) de [usableRatio].
  static int cansForSheetArea(
    double areaMm2, {
    required double canDiameter,
    required double canHeight,
    double usableRatio = 0.8,
  }) {
    final perCan = cylinderLateralArea(canDiameter, canHeight) * usableRatio;
    if (perCan <= 0) return 0;
    return (areaMm2 / perCan).ceil();
  }

  /// Quantités par matériau à partir de la nomenclature (pièces cotées).
  static List<MaterialLine> summarize(TechSheet sheet) {
    final groups = <String, List<TechPart>>{};
    for (final p in sheet.parts) {
      groups.putIfAbsent(p.material.isEmpty ? 'Non précisé' : p.material, () => []).add(p);
    }
    return [
      for (final e in groups.entries)
        MaterialLine(
          material: e.key,
          pieceCount: e.value.fold(0, (a, p) => a + p.quantity),
          linearMm: e.value
              .where((p) => p.shape == PartShape.bar && p.length != null)
              .fold(0.0, (a, p) => a + p.length! * p.quantity),
          areaMm2: e.value.fold(0.0, (a, p) {
            final l = p.length, w = p.width;
            if (l == null || w == null) return a;
            return switch (p.shape) {
              PartShape.sheet || PartShape.box => a + rectangleArea(l, w) * p.quantity,
              PartShape.cylinder => a + cylinderLateralArea(w, l) * p.quantity,
              PartShape.bar => a,
            };
          }),
          volumeMm3: e.value.fold(0.0, (a, p) {
            final l = p.length, w = p.width, t = p.thickness;
            if (p.shape != PartShape.box || l == null || w == null || t == null) return a;
            return a + boxVolume(l, w, t) * p.quantity;
          }),
        ),
    ];
  }

  /// Plan de découpe de toutes les barres cotées, matériau par matériau.
  static Map<String, CutPlan> cutPlans(TechSheet sheet) {
    final byMaterial = <String, List<double>>{};
    for (final p in sheet.parts.where((p) => p.shape == PartShape.bar && p.length != null)) {
      final list = byMaterial.putIfAbsent(p.material.isEmpty ? 'Barre' : p.material, () => []);
      for (var i = 0; i < p.quantity; i++) {
        list.add(p.length!);
      }
    }
    return {
      for (final e in byMaterial.entries)
        e.key: planLinearCuts(e.value, stockLength: sheet.stockLength, kerf: sheet.kerf),
    };
  }

  static BudgetEstimate budget(TechSheet sheet) {
    var total = 0.0;
    var unpriced = 0;
    for (final p in sheet.parts) {
      if (p.unitPrice == null) {
        unpriced++;
      } else {
        total += p.unitPrice! * p.quantity;
      }
    }
    return BudgetEstimate(total, unpriced);
  }

  /// Affichage d'une longueur en mm → « 1 250 mm » ou « 2,4 m ».
  static String formatLength(double mm) {
    if (mm >= 1000) return '${(mm / 1000).toStringAsFixed(2).replaceAll('.', ',')} m';
    return '${mm.round()} mm';
  }

  static String formatArea(double mm2) {
    if (mm2 >= 10000) return '${(mm2 / 1e6).toStringAsFixed(3).replaceAll('.', ',')} m²';
    return '${(mm2 / 100).round()} cm²';
  }
}
