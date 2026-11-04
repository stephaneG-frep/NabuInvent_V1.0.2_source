import 'package:uuid/uuid.dart';

import 'json_utils.dart';

const _uuid = Uuid();

/// Origine d'une donnée technique. Affichée à côté de chaque valeur : on
/// distingue toujours ce que l'utilisateur a mesuré de ce que l'IA suppose.
enum DataSource {
  user('Mesure utilisateur'),
  ai('Hypothèse IA'),
  computed('Calculé'),
  unknown('Inconnu');

  const DataSource(this.label);
  final String label;

  static DataSource fromName(String? name) =>
      DataSource.values.firstWhere((s) => s.name == name, orElse: () => DataSource.ai);
}

/// Forme d'une pièce, qui détermine ses cotes utiles et son dessin.
enum PartShape {
  /// Pavé : longueur × largeur × épaisseur (planche, cale, socle).
  box('Pavé'),

  /// Barre ou tige : longueur (+ section) — entre dans le plan de découpe.
  bar('Barre / tige'),

  /// Feuille : longueur × largeur (tôle, carton, contreplaqué fin).
  sheet('Feuille'),

  /// Cylindre : diamètre × hauteur (boîte de conserve, tube).
  cylinder('Cylindre');

  const PartShape(this.label);
  final String label;

  static PartShape fromName(String? name) =>
      PartShape.values.firstWhere((s) => s.name == name, orElse: () => PartShape.box);
}

/// Orientation d'une pièce dans l'assemblage : direction de sa longueur.
enum PartOrientation {
  /// Couchée à plat : longueur selon la largeur de l'objet, épaisseur vers le haut.
  flat('À plat'),

  /// Debout : longueur vers le haut (pied, montant, cylindre debout).
  upright('Debout'),

  /// En profondeur : longueur vers l'arrière.
  depth('En profondeur');

  const PartOrientation(this.label);
  final String label;

  static PartOrientation fromName(String? name, PartShape shape) =>
      PartOrientation.values.where((o) => o.name == name).firstOrNull ?? defaultFor(shape);

  /// Orientation la plus courante selon la forme.
  static PartOrientation defaultFor(PartShape shape) => switch (shape) {
        PartShape.box => PartOrientation.flat,
        _ => PartOrientation.upright,
      };
}

/// Pièce de la nomenclature. Cotes en millimètres ; null = inconnue.
class TechPart {
  final String id;
  String name;
  String material;
  PartShape shape;
  PartOrientation orientation;
  int quantity;

  /// Longueur (ou hauteur pour un cylindre).
  double? length;

  /// Largeur (ou diamètre pour un cylindre et une barre ronde).
  double? width;

  /// Épaisseur (pavé, feuille).
  double? thickness;

  /// Position du coin bas-gauche-avant dans l'assemblage (mm), pour les vues.
  double x, y, z;
  DataSource source;
  String fastening;

  /// Prix unitaire estimé en euros ; null = inconnu.
  double? unitPrice;

  TechPart({
    String? id,
    required this.name,
    this.material = '',
    this.shape = PartShape.box,
    PartOrientation? orientation,
    this.quantity = 1,
    this.length,
    this.width,
    this.thickness,
    this.x = 0,
    this.y = 0,
    this.z = 0,
    this.source = DataSource.ai,
    this.fastening = '',
    this.unitPrice,
  })  : id = (id == null || id.isEmpty) ? _uuid.v4() : id,
        orientation = orientation ?? PartOrientation.defaultFor(shape);

  /// Cotes indispensables à la fabrication selon la forme.
  List<String> get missingDimensions => [
        if (length == null) shape == PartShape.cylinder ? 'hauteur' : 'longueur',
        if (width == null && shape != PartShape.bar)
          shape == PartShape.cylinder ? 'diamètre' : 'largeur',
        if (thickness == null && (shape == PartShape.box || shape == PartShape.sheet)) 'épaisseur',
      ];

  /// Encombrement (mm) dans l'assemblage : x = largeur de l'objet,
  /// y = hauteur, z = profondeur, selon la forme et l'orientation.
  ({double dx, double dy, double dz}) get extent {
    final l = length ?? 0;
    // Barre : section carrée ou ronde ; cylindre : diamètre dans les deux sens.
    final w = width ?? (shape == PartShape.bar ? 20 : 0);
    final t = switch (shape) {
      PartShape.bar || PartShape.cylinder => w,
      _ => thickness ?? 0,
    };
    return switch (orientation) {
      PartOrientation.flat => (dx: l, dy: t, dz: w),
      PartOrientation.upright => (dx: w, dy: l, dz: t),
      PartOrientation.depth => (dx: w, dy: t, dz: l),
    };
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'material': material,
        'shape': shape.name,
        'orientation': orientation.name,
        'quantity': quantity,
        'length': length,
        'width': width,
        'thickness': thickness,
        'x': x,
        'y': y,
        'z': z,
        'source': source.name,
        'fastening': fastening,
        'unitPrice': unitPrice,
      };

  static double? _mm(Object? v) {
    if (v == null) return null;
    if (v is num) return v > 0 ? v.toDouble() : null;
    final parsed = double.tryParse(v.toString().replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), ''));
    return parsed != null && parsed > 0 ? parsed : null;
  }

  static double _pos(Object? v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);

  factory TechPart.fromJson(Map<String, dynamic> json) {
    final shape = PartShape.fromName(jsonStringOrNull(json['shape']));
    return TechPart(
        id: jsonString(json['id']),
        name: jsonString(json['name'], 'Pièce'),
        material: jsonString(json['material']),
        shape: shape,
        orientation: PartOrientation.fromName(jsonStringOrNull(json['orientation']), shape),
        quantity: jsonInt(json['quantity'], 1, min: 1),
        length: _mm(json['length']),
        width: _mm(json['width'] ?? json['diameter']),
        thickness: _mm(json['thickness']),
        x: _pos(json['x']),
        y: _pos(json['y']),
        z: _pos(json['z']),
        source: DataSource.fromName(jsonStringOrNull(json['source'])),
        fastening: jsonString(json['fastening']),
        unitPrice: _mm(json['unitPrice']),
      );
  }

  TechPart copy() => TechPart.fromJson(toJson());
}

/// Cote d'ensemble (hauteur totale, largeur…), avec son origine.
class TechDimension {
  String label;
  double? value;
  DataSource source;

  TechDimension({required this.label, this.value, this.source = DataSource.unknown});

  Map<String, dynamic> toJson() => {'label': label, 'value': value, 'source': source.name};

  factory TechDimension.fromJson(Map<String, dynamic> json) => TechDimension(
        label: jsonString(json['label']),
        value: TechPart._mm(json['value']),
        source: json['value'] == null
            ? DataSource.unknown
            : DataSource.fromName(jsonStringOrNull(json['source'])),
      );
}

/// Niveau de confiance d'un plan, calculé — jamais déclaré par l'IA.
enum PlanReadiness {
  /// Des cotes indispensables manquent : schéma de principe seulement.
  incomplete('Plan incomplet — mesures manquantes'),

  /// Toutes les cotes existent, mais certaines sont des hypothèses de l'IA.
  hypothetical('Plan indicatif — hypothèses à vérifier'),

  /// Toutes les cotes viennent de l'utilisateur (ou en sont calculées).
  ready('Cotes vérifiées par l\'utilisateur');

  const PlanReadiness(this.label);
  final String label;
}

/// Fiche technique d'un projet.
class TechSheet {
  String objective;
  String method;
  List<TechDimension> dimensions;
  List<TechPart> parts;
  List<String> fasteners;
  List<String> finishes;
  List<String> precautions;

  /// Informations encore inconnues signalées par l'IA ou l'utilisateur.
  List<String> unknowns;

  /// Longueur des barres/tasseaux du commerce pour le plan de découpe (mm).
  double stockLength;

  /// Trait de scie (mm).
  double kerf;

  TechSheet({
    this.objective = '',
    this.method = '',
    List<TechDimension>? dimensions,
    List<TechPart>? parts,
    List<String>? fasteners,
    List<String>? finishes,
    List<String>? precautions,
    List<String>? unknowns,
    this.stockLength = 2400,
    this.kerf = 3,
  })  : dimensions = dimensions ?? [],
        parts = parts ?? [],
        fasteners = fasteners ?? [],
        finishes = finishes ?? [],
        precautions = precautions ?? [],
        unknowns = unknowns ?? [];

  /// Liste lisible de toutes les mesures indispensables manquantes.
  List<String> get missingMeasurements => [
        for (final p in parts)
          for (final m in p.missingDimensions) '${p.name} : $m',
      ];

  PlanReadiness get readiness {
    if (parts.isEmpty || missingMeasurements.isNotEmpty) return PlanReadiness.incomplete;
    if (parts.any((p) => p.source == DataSource.ai || p.source == DataSource.unknown)) {
      return PlanReadiness.hypothetical;
    }
    return PlanReadiness.ready;
  }

  Map<String, dynamic> toJson() => {
        'objective': objective,
        'method': method,
        'dimensions': [for (final d in dimensions) d.toJson()],
        'parts': [for (final p in parts) p.toJson()],
        'fasteners': fasteners,
        'finishes': finishes,
        'precautions': precautions,
        'unknowns': unknowns,
        'stockLength': stockLength,
        'kerf': kerf,
      };

  factory TechSheet.fromJson(Map<String, dynamic> json) => TechSheet(
        objective: jsonString(json['objective']),
        method: jsonString(json['method']),
        dimensions: [
          if (json['dimensions'] is List)
            for (final d in json['dimensions'] as List)
              if (jsonMap(d) case final m?) TechDimension.fromJson(m),
        ],
        parts: [
          if (json['parts'] is List)
            for (final p in json['parts'] as List)
              if (jsonMap(p) case final m?) TechPart.fromJson(m),
        ],
        fasteners: jsonStringList(json['fasteners']),
        finishes: jsonStringList(json['finishes']),
        precautions: jsonStringList(json['precautions']),
        unknowns: jsonStringList(json['unknowns']),
        stockLength: TechPart._mm(json['stockLength']) ?? 2400,
        kerf: TechPart._mm(json['kerf']) ?? 3,
      );

  TechSheet copy() => TechSheet.fromJson(toJson());

  /// Intègre une fiche proposée par l'IA sans jamais écraser une mesure saisie
  /// par l'utilisateur : une pièce de même nom déjà mesurée garde ses cotes.
  TechSheet mergedWith(TechSheet proposal) {
    final merged = proposal.copy();
    for (final p in merged.parts) {
      final mine = parts.where((e) => e.name.toLowerCase() == p.name.toLowerCase()).firstOrNull;
      if (mine != null && mine.source == DataSource.user) {
        p
          ..length = mine.length
          ..width = mine.width
          ..thickness = mine.thickness
          ..quantity = mine.quantity
          ..source = DataSource.user;
      }
    }
    // Pièces ajoutées à la main par l'utilisateur et absentes de la proposition.
    for (final mine in parts.where((e) => e.source == DataSource.user)) {
      if (!merged.parts.any((p) => p.name.toLowerCase() == mine.name.toLowerCase())) {
        merged.parts.add(mine.copy());
      }
    }
    for (final d in merged.dimensions) {
      final mine = dimensions.where((e) => e.label == d.label).firstOrNull;
      if (mine != null && mine.source == DataSource.user) {
        d
          ..value = mine.value
          ..source = DataSource.user;
      }
    }
    merged
      ..stockLength = stockLength
      ..kerf = kerf;
    return merged;
  }
}
