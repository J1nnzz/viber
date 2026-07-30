import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/app_image.dart';

import '../../domain/quiz_models.dart';
import '../quiz_share_sheet.dart';

/// Panel final de partida: celebración o respuesta revelada, con la metadata
/// de la canción. En práctica ofrece "otra canción"; en diario, volver mañana.
class QuizResultPanel extends StatelessWidget {
  final QuizGameState state;
  final VoidCallback? onPlayAgain;

  const QuizResultPanel({super.key, required this.state, this.onPlayAgain});

  @override
  Widget build(BuildContext context) {
    final answer = state.answer;
    return Container(
      padding: const EdgeInsets.all(spacingMd),
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(
          color: state.solved
              ? appSuccess.withValues(alpha: 0.5)
              : appError.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            state.solved
                ? 'quiz.won_in'.tr(args: ['${state.attemptsUsed}'])
                : 'quiz.lost'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: state.solved ? appSuccess : context.appTextPrimColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          // Puntos de ranking ganados (solo reto diario)
          if (!state.practice && state.pointsEarned != null) ...[
            const SizedBox(height: spacingSm),
            Center(child: _pointsPill(context, state.pointsEarned!)),
          ],
          if (answer != null) ...[
            const SizedBox(height: spacingMd),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(radiusMd),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: answer.coverUrl != null
                        ? AppImage(
                            url: answer.coverUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (c) => _coverFallback(c),
                          )
                        : _coverFallback(context),
                  ),
                ),
                const SizedBox(width: spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        answer.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.appTextPrimColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        answer.artistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: context.appTextSecColor, fontSize: 13),
                      ),
                      const SizedBox(height: spacingXs),
                      Wrap(
                        spacing: spacingXs,
                        runSpacing: spacingXs,
                        children: [
                          if (answer.releaseYear != null)
                            _chip(context, '${answer.releaseYear}'),
                          if (answer.genre != null)
                            _chip(context, answer.genre!),
                          if (answer.durationSec != null)
                            _chip(context, _duration(answer.durationSec!)),
                          if (answer.explicit == true)
                            _chip(context, '🅴'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: spacingMd),
          // Resultado compartible (spoiler-free) — motor de crecimiento social
          OutlinedButton.icon(
            onPressed: () => showQuizShareSheet(context, state),
            icon: const Icon(Icons.share_rounded, size: 18),
            label: Text('quiz.share_button'.tr()),
          ),
          const SizedBox(height: spacingSm),
          if (state.practice && onPlayAgain != null)
            ElevatedButton.icon(
              onPressed: onPlayAgain,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('quiz.play_again'.tr()),
            )
          else if (!state.practice)
            Column(
              children: [
                if (state.dailySolvedCount != null)
                  Text(
                    'quiz.solved_today'
                        .tr(args: ['${state.dailySolvedCount}']),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: context.appTextSecColor, fontSize: 12),
                  ),
                const SizedBox(height: spacingXs),
                Text(
                  'quiz.come_back'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: appAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _pointsPill(BuildContext context, int points) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: spacingMd, vertical: 6),
        decoration: BoxDecoration(
          color: context.appAccentDimColor,
          borderRadius: BorderRadius.circular(radiusFull),
          border: Border.all(color: context.appAccentColor.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.stars_rounded, size: 16, color: context.appAccentColor),
            const SizedBox(width: 6),
            Text(
              'quiz.points_earned'.tr(args: ['$points']),
              style: TextStyle(
                color: context.appAccentColor,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );

  Widget _coverFallback(BuildContext context) => Container(
        color: context.appCard2Color,
        child: Icon(Icons.music_note_rounded,
            size: 28, color: context.appTextDimColor),
      );

  Widget _chip(BuildContext context, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: context.appCard2Color,
          borderRadius: BorderRadius.circular(radiusFull),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: context.appTextSecColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  static String _duration(int seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
