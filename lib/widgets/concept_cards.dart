import 'package:flutter/material.dart';

import '../models/concept.dart';
import 'common.dart';
import 'invention_sections.dart';

/// Variantes proposées par l'atelier, regroupées par objet (« Canard »,
/// « Héron »…), avec un bouton pour choisir librement l'une d'elles.
class ConceptGalleryCard extends StatelessWidget {
  final List<InventionConcept> concepts;
  final List<String> resources;
  final void Function(InventionConcept concept)? onChoose;
  final bool Function(InventionConcept concept)? isChosen;

  const ConceptGalleryCard({
    super.key,
    required this.concepts,
    this.resources = const [],
    this.onChoose,
    this.isChosen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = groupConceptsBySubject(concepts);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (resources.isNotEmpty) ...[
            Text('Ressources identifiées',
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TagChips(resources),
            const SizedBox(height: 10),
          ],
          for (final entry in groups.entries) ...[
            if (groups.length > 1 || entry.key != 'Propositions')
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 6),
                child: Text(entry.key,
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
              ),
            for (var i = 0; i < entry.value.length; i++)
              ConceptTile(
                concept: entry.value[i],
                index: i + 1,
                chosen: isChosen?.call(entry.value[i]) ?? false,
                onChoose: onChoose == null ? null : () => onChoose!(entry.value[i]),
              ),
          ],
        ],
      ),
    );
  }
}

class ConceptTile extends StatelessWidget {
  final InventionConcept concept;
  final int index;
  final bool chosen;
  final VoidCallback? onChoose;

  const ConceptTile({
    super.key,
    required this.concept,
    required this.index,
    this.chosen = false,
    this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = concept;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text('$index',
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      if (c.style.isNotEmpty)
                        Text(c.style,
                            style: theme.textTheme.labelMedium
                                ?.copyWith(color: theme.colorScheme.primary)),
                    ],
                  ),
                ),
                if (c.feasibility > 0) ScoreRing(c.feasibility, size: 34),
              ],
            ),
            if (c.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(c.description, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
            ],
            if (c.why.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(c.why,
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic, color: theme.colorScheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 8),
            BudgetSection(budget: c.budget, time: c.time, difficulty: c.difficulty),
            if (c.dimensions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.straighten, size: 15, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Dimensions : ${c.dimensions}',
                        style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ],
            CollapsibleSection(
              title: 'Détails',
              icon: Icons.list_alt,
              initiallyExpanded: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (c.materials.isNotEmpty) _labeledList(context, 'Matériaux', c.materials),
                  if (c.advantages.isNotEmpty) _labeledList(context, 'Avantages', c.advantages),
                  if (c.constraints.isNotEmpty)
                    _labeledList(context, 'Contraintes', c.constraints),
                ],
              ),
            ),
            if (onChoose != null)
              Align(
                alignment: Alignment.centerRight,
                child: chosen
                    ? const Chip(
                        avatar: Icon(Icons.check_circle, size: 18, color: Colors.green),
                        label: Text('Projet créé'),
                      )
                    : FilledButton.tonalIcon(
                        onPressed: onChoose,
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Choisir ce concept'),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _labeledList(BuildContext context, String title, List<String> items) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('• $i', style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}
