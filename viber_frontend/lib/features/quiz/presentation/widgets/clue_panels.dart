import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:viber/core/theme/app_theme.dart';

/// Paneles de pista de los modos letra, portada y emojis.
/// (El del modo audio es SnippetPlayer, en su propio archivo.)

// ── Letra ─────────────────────────────────────────────────────────────────────

/// Muestra las líneas de letra reveladas hasta ahora. El backend ya manda las
/// palabras del título censuradas como "____" mientras la partida siga viva.
class LyricsCluePanel extends StatelessWidget {
  final List<String> lines;

  const LyricsCluePanel({super.key, required this.lines});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(spacingMd),
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: context.appDividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_quote_rounded,
                  color: context.appTextSecColor, size: 18),
              const SizedBox(width: spacingXs),
              Text(
                'quiz.lyrics_censor_note'.tr(),
                style: TextStyle(
                    color: context.appTextSecColor, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: spacingSm),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                line,
                style: TextStyle(
                  color: context.appTextPrimColor,
                  fontSize: 14.5,
                  fontStyle: FontStyle.italic,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Portada ───────────────────────────────────────────────────────────────────

/// Portada pixelada por el servidor. [version] fuerza la recarga cuando se
/// gasta un intento (el navegador cachearía la misma URL).
class CoverCluePanel extends StatelessWidget {
  final String imageUrl;
  final int version;

  const CoverCluePanel({
    super.key,
    required this.imageUrl,
    required this.version,
  });

  @override
  Widget build(BuildContext context) {
    final url = '$imageUrl&v=$version';
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radiusLg),
        child: Container(
          width: 230,
          height: 230,
          color: context.appCard2Color,
          // FilterQuality.none mantiene los píxeles nítidos al escalar el
          // PNG diminuto (p. ej. 8×8) que manda el backend
          child: Image.network(
            url,
            key: ValueKey(url),
            width: 230,
            height: 230,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
            gaplessPlayback: true,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
            errorBuilder: (_, _, _) => Icon(Icons.broken_image_outlined,
                size: 40, color: context.appTextDimColor),
          ),
        ),
      ),
    );
  }
}

// ── Emojis ────────────────────────────────────────────────────────────────────

/// Emojis revelados + cajas "?" por los que quedan ocultos.
class EmojiCluePanel extends StatelessWidget {
  final String visible; // "🌧️ 🔥"
  final int total;

  const EmojiCluePanel({super.key, required this.visible, required this.total});

  @override
  Widget build(BuildContext context) {
    final shown =
        visible.split(' ').where((e) => e.trim().isNotEmpty).toList();
    final hidden = (total - shown.length).clamp(0, total);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          vertical: spacingLg, horizontal: spacingMd),
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: context.appDividerColor),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: spacingSm,
        runSpacing: spacingSm,
        children: [
          for (final e in shown)
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.appAccentGlowColor,
                borderRadius: BorderRadius.circular(radiusMd),
              ),
              child: Text(e, style: const TextStyle(fontSize: 28)),
            ),
          for (int i = 0; i < hidden; i++)
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.appCard2Color,
                borderRadius: BorderRadius.circular(radiusMd),
                border: Border.all(color: context.appDividerColor),
              ),
              child: Text(
                '?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: context.appTextDimColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
