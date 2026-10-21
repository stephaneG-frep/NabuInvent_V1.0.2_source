import 'package:flutter/material.dart';

import '../models/invention_project.dart';
import 'common.dart';

class ProjectCard extends StatelessWidget {
  final InventionProject project;
  final VoidCallback onTap;
  final VoidCallback? onStar;
  const ProjectCard({super.key, required this.project, required this.onTap, this.onStar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = project;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: p.status.color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(p.status.icon, color: p.status.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.title,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        if (p.subtitle.isNotEmpty || p.category.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            p.subtitle.isNotEmpty
                                ? p.subtitle
                                : p.category,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (onStar != null)
                    IconButton(
                      onPressed: onStar,
                      icon: Icon(
                        p.starred ? Icons.star : Icons.star_outline,
                        color: p.starred ? const Color(0xFFF6BF26) : theme.colorScheme.outline,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  StatusPill(p.status),
                  const Spacer(),
                  if (p.score > 0) ...[
                    ScoreRing(p.score, size: 34),
                    const SizedBox(width: 8),
                  ],
                  if (p.hasPlan) ...[
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${(p.buildProgress * 100).round()} %',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        SizedBox(
                          width: 54,
                          child: LinearProgressIndicator(
                            value: p.buildProgress,
                            minHeight: 5,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              if (p.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                TagChips(p.tags),
              ],
            ],
          ),
        ),
      ),
    );
  }
}