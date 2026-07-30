import 'package:flutter/material.dart';

/// Renders a message with @mention tokens highlighted.
///
/// • @myUsername  → tinted pill with border (visually prominent)
/// • @others      → bold + underline in accentColor
///
/// Pass [onDarkBg] = true when the text sits on a colored bubble
/// (e.g. your own messages), so the pill uses a white/translucent style
/// instead of the accent color, which would be invisible.
class MentionText extends StatelessWidget {
  final String text;
  final String? myUsername;
  final TextStyle baseStyle;
  final Color accentColor;
  final bool onDarkBg;

  const MentionText({
    super.key,
    required this.text,
    this.myUsername,
    required this.baseStyle,
    required this.accentColor,
    this.onDarkBg = false,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: _buildSpans(), style: baseStyle),
    );
  }

  List<InlineSpan> _buildSpans() {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'(@\w+)');
    int last = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }

      final mention = match.group(0)!;
      final mentionUser = mention.substring(1).toLowerCase();
      final isMe = myUsername != null &&
          mentionUser == myUsername!.toLowerCase();

      if (isMe) {
        // ── @myUsername → pill ──────────────────────────────────────────
        final pillBg   = onDarkBg
            ? Colors.white.withValues(alpha: 0.25)
            : accentColor.withValues(alpha: 0.18);
        final pillBorder = onDarkBg
            ? Colors.white.withValues(alpha: 0.55)
            : accentColor.withValues(alpha: 0.55);
        final pillText = onDarkBg ? Colors.white : accentColor;

        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: pillBorder, width: 1),
            ),
            child: Text(
              mention,
              style: baseStyle.copyWith(
                color:      pillText,
                fontWeight: FontWeight.w800,
                fontSize:   (baseStyle.fontSize ?? 14) * 0.93,
                height:     1,
              ),
            ),
          ),
        ));
      } else {
        // ── @someone → bold + underline ─────────────────────────────────
        spans.add(TextSpan(
          text: mention,
          style: baseStyle.copyWith(
            color:          accentColor,
            fontWeight:     FontWeight.w700,
            decoration:     TextDecoration.underline,
            decorationColor: accentColor,
          ),
        ));
      }

      last = match.end;
    }

    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }

    return spans;
  }
}
