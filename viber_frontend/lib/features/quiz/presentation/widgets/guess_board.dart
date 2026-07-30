import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/motion.dart';

import '../../domain/quiz_models.dart';

/// Color de las casillas "cerca" (amarillo) — no existe en los design tokens.
const Color quizClose = Color(0xFFE5A53A);

/// Tablero del modo clásico: una tarjeta por intento (el más reciente arriba)
/// con las 5 casillas de comparación estilo LoLdle.
class ClassicGuessBoard extends StatelessWidget {
  final List<QuizGuessResult> guesses;

  /// Nº de intento (1-based) que acaba de hacerse: esa fila reacciona con
  /// "pop" (acierto) o sacudida (fallo). El resto entra de forma neutra.
  final int? reactAttempt;

  const ClassicGuessBoard({
    super.key,
    required this.guesses,
    this.reactAttempt,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // El intento más reciente arriba, numerado por orden de juego
        for (int i = guesses.length - 1; i >= 0; i--) ...[
          _GuessRow(
            key: ValueKey('classic_guess_${i + 1}'),
            guess: guesses[i],
            attemptNumber: i + 1,
            react: reactAttempt == i + 1,
          ),
          const SizedBox(height: spacingSm),
        ],
      ],
    );
  }
}

class _GuessRow extends StatelessWidget {
  final QuizGuessResult guess;
  final int attemptNumber;
  final bool react;

  const _GuessRow({
    super.key,
    required this.guess,
    required this.attemptNumber,
    this.react = false,
  });

  @override
  Widget build(BuildContext context) {
    final song = guess.song;
    final kind = !react
        ? FeedbackKind.entrance
        : (guess.correct ? FeedbackKind.success : FeedbackKind.error);
    return FeedbackEntrance(
      kind: kind,
      child: Container(
      padding: const EdgeInsets.all(spacingSm),
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(
          color: guess.correct
              ? appSuccess.withValues(alpha: 0.6)
              : context.appDividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Cabecera: nº de intento + canción probada ────────────────────
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.appCard2Color,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$attemptNumber',
                  style: TextStyle(
                    color: context.appTextSecColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: spacingSm),
              Expanded(
                child: Text(
                  song != null ? '${song.title} — ${song.artistName}' : '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.appTextPrimColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (guess.correct)
                const Icon(Icons.check_circle_rounded,
                    color: appSuccess, size: 18),
            ],
          ),
          const SizedBox(height: spacingSm),
          // ── Casillas ─────────────────────────────────────────────────────
          Row(
            children: [
              _AttributeCell(label: 'quiz.col_artist'.tr(), field: guess.artist),
              const SizedBox(width: spacingXs),
              _AttributeCell(label: 'quiz.col_genre'.tr(), field: guess.genre),
              const SizedBox(width: spacingXs),
              _AttributeCell(label: 'quiz.col_year'.tr(), field: guess.year),
              const SizedBox(width: spacingXs),
              _AttributeCell(
                label: 'quiz.col_duration'.tr(),
                field: guess.duration,
                formatValue: _formatDuration,
              ),
              const SizedBox(width: spacingXs),
              _AttributeCell(
                label: 'quiz.col_explicit'.tr(),
                field: guess.explicit,
                formatValue: (v) => v == 'true' ? '🅴' : '—',
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  static String _formatDuration(String seconds) {
    final total = int.tryParse(seconds);
    if (total == null) return seconds;
    final m = total ~/ 60;
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _AttributeCell extends StatelessWidget {
  final String label;
  final FieldComparison? field;
  final String Function(String value)? formatValue;

  const _AttributeCell({required this.label, this.field, this.formatValue});

  @override
  Widget build(BuildContext context) {
    final f = field;
    final Color color = f == null
        ? context.appTextDimColor
        : f.isCorrect
            ? appSuccess
            : f.isClose
                ? quizClose
                : appError;

    final value = f == null
        ? '?'
        : (formatValue != null ? formatValue!(f.value) : f.value);

    return Expanded(
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(radiusSm),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.appTextSecColor,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    value,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.appTextPrimColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                ),
                if (f != null && (f.answerIsHigher || f.answerIsLower))
                  Icon(
                    f.answerIsHigher
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 12,
                    color: color,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Leyenda de colores compartida por las pantallas del quiz.
class QuizLegend extends StatelessWidget {
  const QuizLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 4),
            Text(text,
                style:
                    TextStyle(color: context.appTextSecColor, fontSize: 11)),
          ],
        );

    return Wrap(
      spacing: spacingMd,
      runSpacing: spacingXs,
      alignment: WrapAlignment.center,
      children: [
        item(appSuccess, 'quiz.legend_correct'.tr()),
        item(quizClose, 'quiz.legend_close'.tr()),
        item(appError, 'quiz.legend_wrong'.tr()),
      ],
    );
  }
}
