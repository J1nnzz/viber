import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/app_image.dart';

import '../../domain/quiz_models.dart';

/// Enlace de la app para los resultados compartidos del quiz.
/// TODO: sustituir por el dominio real cuando esté desplegado.
const String quizShareUrl = 'https://viber.app/quiz';

/// Tarjeta visual del resultado del quiz, pensada para exportarse a imagen y
/// compartirse en WhatsApp/Instagram/etc.
///
/// Usa SIEMPRE la paleta oscura (no depende del tema activo) para que la imagen
/// compartida tenga un aspecto de marca consistente. La rejilla de intentos se
/// dibuja con casillas de color reales (no emojis) para una captura nítida.
class QuizShareCard extends StatelessWidget {
  final QuizGameState state;
  final double width;

  const QuizShareCard({super.key, required this.state, this.width = 360});

  @override
  Widget build(BuildContext context) {
    final answer = state.answer;
    final mode = 'quiz.${state.mode.name}_title'.tr();
    final subtitle =
        (state.practice || state.date == null) ? mode : '$mode · ${state.date}';

    // En el reto diario la canción es la misma para todos, así que ocultamos su
    // reveal (portada + título) para no destripar el reto a quien vea la imagen.
    // En práctica cada uno tiene una canción distinta → se puede mostrar.
    final hideAnswer = !state.practice && state.date != null;

    return Container(
      width: width,
      padding: const EdgeInsets.all(spacingLg),
      decoration: BoxDecoration(
        color: appBg,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: appAccent.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Cabecera de marca ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/brand/isotipo.png',
                  height: 26, filterQuality: FilterQuality.medium),
              const SizedBox(width: spacingSm),
              ShaderMask(
                shaderCallback: (r) => appBrandGradient.createShader(r),
                blendMode: BlendMode.srcIn,
                child: const Text(
                  'VIBER QUIZ',
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: Colors.white, // lo pinta el shader
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: spacingXs),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: appTextSec, fontSize: 12, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: spacingLg),

          // ── Rejilla de intentos ────────────────────────────────────────
          _grid(),

          const SizedBox(height: spacingMd),

          // ── Resultado ──────────────────────────────────────────────────
          Text(
            state.solved
                ? 'quiz.won_in'.tr(args: ['${state.attemptsUsed}'])
                : 'quiz.lost'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: state.solved ? appSuccess : appError,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),

          // ── Canción ────────────────────────────────────────────────────
          if (answer != null) ...[
            const SizedBox(height: spacingLg),
            hideAnswer ? _hiddenSong() : _revealedSong(answer),
          ],

          const SizedBox(height: spacingLg),
          Text(
            'viber.app',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: appAccent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // Canción revelada (práctica): portada + título + artista.
  Widget _revealedSong(QuizAnswer answer) => Container(
        padding: const EdgeInsets.all(spacingSm),
        decoration: BoxDecoration(
          color: appCard2,
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(radiusSm),
              child: SizedBox(
                width: 52,
                height: 52,
                child: answer.coverUrl != null
                    ? AppImage(
                        url: answer.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (c) => _coverFallback(),
                      )
                    : _coverFallback(),
              ),
            ),
            const SizedBox(width: spacingSm),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    answer.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: appTextPrim,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    answer.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: appTextSec, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  // Canción oculta (reto diario): portada y título tapados para no hacer spoiler.
  Widget _hiddenSong() => Container(
        padding: const EdgeInsets.all(spacingSm),
        decoration: BoxDecoration(
          color: appCard2,
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: appBg,
                borderRadius: BorderRadius.circular(radiusSm),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.lock_rounded, color: appTextDim, size: 22),
            ),
            const SizedBox(width: spacingSm),
            Expanded(
              child: Text(
                'quiz.share_hidden_song'.tr(),
                style: const TextStyle(
                  color: appTextSec,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _grid() => Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: state.guesses.map((g) {
          final color = g.skipped
              ? appTextDim.withValues(alpha: 0.4)
              : g.correct
                  ? appSuccess
                  : appError;
          return Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          );
        }).toList(),
      );

  Widget _coverFallback() => Container(
        color: appCard2,
        child: const Icon(Icons.music_note_rounded, color: appTextDim, size: 22),
      );
}
