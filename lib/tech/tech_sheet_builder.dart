import '../models/invention_project.dart';
import '../models/tech_sheet.dart';
import 'safety_checker.dart';

/// Construit une fiche technique de départ à partir d'un projet, sans IA :
/// une pièce par matériau, forme devinée d'après le nom, **cotes inconnues**
/// (à mesurer par l'utilisateur). Rien n'est inventé.
class TechSheetBuilder {
  TechSheetBuilder._();

  static PartShape guessShape(String material) {
    final m = material.toLowerCase();
    if (RegExp(r'conserve|canette|bo[iî]te|bouteille|pot\b|tube en carton|cylindre').hasMatch(m)) {
      return PartShape.cylinder;
    }
    if (RegExp(r'tasseau|tige|fil|barre|tube|baguette|profil|cornière|tuyau|manche').hasMatch(m)) {
      return PartShape.bar;
    }
    if (RegExp(r't[oô]le|carton|feuille|plaque|contreplaqu|tissu|bâche|bache|film').hasMatch(m)) {
      return PartShape.sheet;
    }
    return PartShape.box;
  }

  static bool _isFastener(String m) =>
      RegExp(r'\bvis\b|clou|rivet|boulon|écrou|ecrou|rondelle|colle|charnière|charniere|équerre|equerre|agrafe|serre-c[aâ]ble',
              caseSensitive: false)
          .hasMatch(m);

  static bool _isFinish(String m) =>
      RegExp(r'peinture|vernis|lasure|huile|cire|antirouille|apprêt|appret', caseSensitive: false)
          .hasMatch(m);

  /// Quantité en tête du libellé (« 4 boîtes de conserve » → 4).
  static int _quantity(String m) =>
      int.tryParse(RegExp(r'^\s*(\d{1,3})\b').firstMatch(m)?.group(1) ?? '') ?? 1;

  static TechSheet fromProject(InventionProject p) {
    final parts = <TechPart>[];
    final fasteners = <String>[];
    final finishes = <String>[];
    for (final m in p.materials) {
      if (_isFastener(m)) {
        fasteners.add(m);
      } else if (_isFinish(m)) {
        finishes.add(m);
      } else {
        parts.add(TechPart(
          name: m.replaceFirst(RegExp(r'^\s*\d{1,3}\s*(?:x|×)?\s*'), ''),
          material: m,
          shape: guessShape(m),
          quantity: _quantity(m),
          source: DataSource.unknown,
        ));
      }
    }
    return TechSheet(
      objective: p.problem.isNotEmpty ? p.problem : p.concept,
      method: p.mechanism,
      dimensions: [
        TechDimension(label: 'Hauteur totale'),
        TechDimension(label: 'Largeur totale'),
        TechDimension(label: 'Profondeur totale'),
      ],
      parts: parts,
      fasteners: fasteners,
      finishes: finishes,
      precautions: [for (final f in SafetyChecker.checkProject(p)) f.text],
      unknowns: [
        if (parts.isNotEmpty) 'Cotes de chaque pièce (à mesurer sur tes matériaux)',
        'Dimensions totales souhaitées',
      ],
    );
  }
}
