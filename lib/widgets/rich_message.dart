import 'package:flutter/material.dart';

/// Type d'un bloc de texte mis en forme.
enum RichBlockKind { heading1, heading2, heading3, paragraph, bullet, numbered, quote }

/// Bloc de texte issu de la mise en forme légère (titres #, listes -, 1.).
class RichBlock {
  final RichBlockKind kind;
  final String text;

  /// Numéro affiché pour une liste numérotée.
  final String? marker;

  const RichBlock(this.kind, this.text, {this.marker});
}

/// Découpe un texte (mise en forme type Markdown légère) en blocs.
/// Fonction pure, testable sans interface.
List<RichBlock> parseRichBlocks(String text) {
  final blocks = <RichBlock>[];
  final paragraph = <String>[];

  void flush() {
    if (paragraph.isEmpty) return;
    blocks.add(RichBlock(RichBlockKind.paragraph, paragraph.join('\n')));
    paragraph.clear();
  }

  for (final rawLine in text.replaceAll('\r\n', '\n').split('\n')) {
    final line = rawLine.trimRight();
    final t = line.trimLeft();
    if (t.isEmpty) {
      flush();
      continue;
    }
    final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(t);
    if (heading != null) {
      flush();
      final level = heading.group(1)!.length;
      blocks.add(RichBlock(
        level == 1
            ? RichBlockKind.heading1
            : level == 2
                ? RichBlockKind.heading2
                : RichBlockKind.heading3,
        heading.group(2)!,
      ));
      continue;
    }
    final bullet = RegExp(r'^[-*•]\s+(.*)$').firstMatch(t);
    if (bullet != null) {
      flush();
      blocks.add(RichBlock(RichBlockKind.bullet, bullet.group(1)!));
      continue;
    }
    final numbered = RegExp(r'^(\d{1,3})[.)]\s+(.*)$').firstMatch(t);
    if (numbered != null) {
      flush();
      blocks.add(RichBlock(RichBlockKind.numbered, numbered.group(2)!,
          marker: '${numbered.group(1)}.'));
      continue;
    }
    if (t.startsWith('> ')) {
      flush();
      blocks.add(RichBlock(RichBlockKind.quote, t.substring(2)));
      continue;
    }
    paragraph.add(t);
  }
  flush();
  return blocks;
}

/// Affiche un message de l'IA mis en forme. Aucun défilement interne : le
/// bloc prend la hauteur de son contenu et la conversation défile d'un seul
/// tenant. La sélection est assurée par la `SelectionArea` de la bulle.
class RichMessage extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const RichMessage(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = style ?? theme.textTheme.bodyMedium!;
    final blocks = parseRichBlocks(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : _gapBefore(blocks[i].kind)),
            child: _block(context, blocks[i], base),
          ),
      ],
    );
  }

  double _gapBefore(RichBlockKind kind) => switch (kind) {
        RichBlockKind.heading1 || RichBlockKind.heading2 => 12,
        RichBlockKind.heading3 => 10,
        RichBlockKind.bullet || RichBlockKind.numbered => 4,
        _ => 8,
      };

  Widget _block(BuildContext context, RichBlock b, TextStyle base) {
    final theme = Theme.of(context);
    switch (b.kind) {
      case RichBlockKind.heading1:
      case RichBlockKind.heading2:
      case RichBlockKind.heading3:
        final size = b.kind == RichBlockKind.heading1
            ? 1.3
            : b.kind == RichBlockKind.heading2
                ? 1.18
                : 1.06;
        return Text.rich(
          TextSpan(children: inlineSpans(b.text, base)),
          style: base.copyWith(
            fontSize: (base.fontSize ?? 14) * size,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        );
      case RichBlockKind.bullet:
      case RichBlockKind.numbered:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              child: Text(
                b.marker ?? '•',
                style: base.copyWith(
                    color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: Text.rich(TextSpan(children: inlineSpans(b.text, base)),
                  style: base.copyWith(height: 1.4)),
            ),
          ],
        );
      case RichBlockKind.quote:
        return Container(
          padding: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            border: Border(
                left: BorderSide(color: theme.colorScheme.primary, width: 3)),
          ),
          child: Text.rich(TextSpan(children: inlineSpans(b.text, base)),
              style: base.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant)),
        );
      case RichBlockKind.paragraph:
        return Text.rich(TextSpan(children: inlineSpans(b.text, base)),
            style: base.copyWith(height: 1.45));
    }
  }

  /// Gras (**texte**) et code (`texte`) dans une ligne.
  static List<InlineSpan> inlineSpans(String text, TextStyle base) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`');
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      if (m.group(1) != null) {
        spans.add(TextSpan(
            text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w700)));
      } else {
        spans.add(TextSpan(
            text: m.group(2),
            style: TextStyle(
                fontFamily: 'monospace', fontSize: (base.fontSize ?? 14) * 0.92)));
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }
}
