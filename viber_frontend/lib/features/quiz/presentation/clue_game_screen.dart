import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/utils/haptics.dart';
import 'package:viber/core/widgets/app_image.dart';
import 'package:viber/core/widgets/app_snack_bar.dart';
import 'package:viber/core/widgets/motion.dart';

import '../application/quiz_use_cases.dart';
import '../domain/quiz_models.dart';
import '../infrastructure/quiz_service.dart';
import 'widgets/clue_panels.dart';
import 'widgets/guess_board.dart' show quizClose;
import 'widgets/quiz_result_panel.dart';
import 'widgets/snippet_player.dart';
import 'widgets/song_autocomplete_field.dart';

/// Pantalla común de los modos de pista (audio, letra, portada, emojis):
/// 6 intentos, y con cada fallo o salto la pista crece — más segundos de
/// preview, una línea más de letra, portada con más resolución o un emoji más.
class ClueGameScreen extends StatefulWidget {
  final QuizMode mode;
  final bool practice;

  const ClueGameScreen({super.key, required this.mode, required this.practice})
      : assert(mode != QuizMode.classic, 'El modo clásico tiene su pantalla');

  @override
  State<ClueGameScreen> createState() => _ClueGameScreenState();
}

class _ClueGameScreenState extends State<ClueGameScreen> {
  final _service = QuizService();
  late final _getDaily = GetDailyQuizGameUseCase(_service);
  late final _newPractice = NewPracticeQuizGameUseCase(_service);
  late final _guess = GuessQuizSongUseCase(_service);
  late final _skip = SkipQuizTurnUseCase(_service);

  QuizGameState? _state;
  String? _mediaUrl; // audio o portada según el modo
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  /// Nº del intento recién jugado: esa fila del historial reacciona.
  int? _reactAttempt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _mediaUrl = null;
    });
    try {
      final state = widget.practice
          ? await _newPractice(widget.mode)
          : await _getDaily(widget.mode);

      String? mediaUrl;
      if (widget.mode == QuizMode.audio) {
        mediaUrl = await _service.audioUrl(state.gameId);
      } else if (widget.mode == QuizMode.cover) {
        mediaUrl = await _service.coverUrl(state.gameId);
      }

      if (mounted) {
        setState(() {
          _state = state;
          _mediaUrl = mediaUrl;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<QuizGameState> Function() action) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final updated = await action();
      if (mounted) {
        setState(() {
          _state = updated;
          _reactAttempt = updated.guesses.length;
        });
        final last = updated.guesses.isNotEmpty ? updated.guesses.last : null;
        if (last != null && !last.skipped) {
          if (last.correct) {
            Haptics.success();
          } else {
            Haptics.error();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context,
            e.toString().replaceAll('Exception: ', ''), error: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String get _modeTitle => 'quiz.${widget.mode.name}_title'.tr();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.practice
              ? '$_modeTitle — ${'quiz.practice'.tr()}'
              : '$_modeTitle — ${'quiz.daily'.tr()}',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildGame(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(spacingLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 48, color: context.appTextDimColor),
            const SizedBox(height: spacingMd),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appTextSecColor, fontSize: 14),
            ),
            const SizedBox(height: spacingMd),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('common.refresh'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGame() {
    final state = _state!;
    final maxAttempts = state.maxAttempts ?? 6;
    final guessedIds =
        state.guesses.map((g) => g.song?.id).whereType<int>().toSet();

    return ListView(
      padding: const EdgeInsets.all(spacingMd),
      children: [
        // ── Contador de intentos ─────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < maxAttempts; i++)
              Container(
                width: 26,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i < state.attemptsUsed
                      ? (state.solved && i == state.attemptsUsed - 1
                          ? appSuccess
                          : appError.withValues(alpha: 0.7))
                      : context.appCard2Color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
        const SizedBox(height: spacingXs),
        Center(
          child: Text(
            '${state.attemptsUsed} / $maxAttempts',
            style: TextStyle(color: context.appTextSecColor, fontSize: 12),
          ),
        ),
        const SizedBox(height: spacingMd),

        // ── Pista según el modo ──────────────────────────────────────────────
        _buildClue(state),
        const SizedBox(height: spacingMd),

        // ── Acciones ─────────────────────────────────────────────────────────
        if (!state.finished) ...[
          SongAutocompleteField(
            mode: widget.mode,
            enabled: !_submitting,
            excludedIds: guessedIds,
            showCovers: widget.mode != QuizMode.cover,
            onSelected: (song) => _run(() => _guess(_state!.gameId, song.id)),
          ),
          const SizedBox(height: spacingSm),
          OutlinedButton.icon(
            onPressed:
                _submitting ? null : () => _run(() => _skip(_state!.gameId)),
            icon: const Icon(Icons.skip_next_rounded, size: 18),
            label: Text(_skipLabel(state)),
          ),
        ] else
          QuizResultPanel(
            state: state,
            onPlayAgain: widget.practice ? _load : null,
          ),

        const SizedBox(height: spacingMd),

        // ── Historial de intentos ────────────────────────────────────────────
        for (int i = state.guesses.length - 1; i >= 0; i--)
          _AttemptTile(
            key: ValueKey('clue_attempt_${i + 1}'),
            guess: state.guesses[i],
            number: i + 1,
            react: _reactAttempt == i + 1,
          ),
      ],
    );
  }

  Widget _buildClue(QuizGameState state) {
    switch (widget.mode) {
      case QuizMode.audio:
        if (_mediaUrl == null) return const SizedBox.shrink();
        return SnippetPlayer(
          audioUrl: _mediaUrl!,
          unlockedSeconds: state.unlockedSeconds ?? 1,
          steps: state.snippetSteps ?? const [1, 2, 4, 7, 12, 30],
          finished: state.finished,
        );

      case QuizMode.lyrics:
        return LyricsCluePanel(lines: state.lyricsLines ?? const []);

      case QuizMode.cover:
        // Al terminar, la portada real sin pixelar (viene en answer)
        if (state.finished && state.answer?.coverUrl != null) {
          return Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radiusLg),
              child: AppImage(
                url: state.answer!.coverUrl!,
                width: 230,
                height: 230,
              ),
            ),
          );
        }
        if (_mediaUrl == null) return const SizedBox.shrink();
        return CoverCluePanel(
            imageUrl: _mediaUrl!, version: state.attemptsUsed);

      case QuizMode.emoji:
        return EmojiCluePanel(
          visible: state.emojisVisible ?? '',
          total: state.emojisTotal ?? 0,
        );

      case QuizMode.classic:
        return const SizedBox.shrink(); // no llega: el clásico tiene su pantalla
    }
  }

  String _skipLabel(QuizGameState state) {
    if (widget.mode == QuizMode.audio) {
      final steps = state.snippetSteps ?? const [1, 2, 4, 7, 12, 30];
      final nextStep = state.attemptsUsed + 1 < steps.length
          ? steps[state.attemptsUsed + 1] - steps[state.attemptsUsed]
          : 0;
      return nextStep > 0
          ? 'quiz.skip'.tr(args: ['$nextStep'])
          : 'quiz.skip_last'.tr();
    }
    final isLast = state.attemptsUsed + 1 >= (state.maxAttempts ?? 6);
    return isLast ? 'quiz.skip_last'.tr() : 'quiz.skip_generic'.tr();
  }
}

// ── Fila del historial de intentos ────────────────────────────────────────────

class _AttemptTile extends StatelessWidget {
  final QuizGuessResult guess;
  final int number;
  final bool react;

  const _AttemptTile({
    super.key,
    required this.guess,
    required this.number,
    this.react = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String text;
    final IconData icon;

    if (guess.skipped) {
      color = context.appTextDimColor;
      text = 'quiz.skipped'.tr();
      icon = Icons.skip_next_rounded;
    } else if (guess.correct) {
      color = appSuccess;
      text = '${guess.song!.title} — ${guess.song!.artistName}';
      icon = Icons.check_circle_rounded;
    } else if (guess.artistMatch == true) {
      // Mismo artista: casi casi
      color = quizClose;
      text = '${guess.song!.title} — ${guess.song!.artistName}';
      icon = Icons.person_rounded;
    } else {
      color = appError;
      text = '${guess.song!.title} — ${guess.song!.artistName}';
      icon = Icons.close_rounded;
    }

    // Saltar no es un fallo que castigar → entrada neutra. Acierto: pop.
    final kind = !react || guess.skipped
        ? FeedbackKind.entrance
        : guess.correct
            ? FeedbackKind.success
            : FeedbackKind.error;

    return FeedbackEntrance(
      kind: kind,
      child: Container(
      margin: const EdgeInsets.only(bottom: spacingSm),
      padding: const EdgeInsets.symmetric(
          horizontal: spacingSm, vertical: spacingSm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Text(
            '$number',
            style: TextStyle(
              color: context.appTextDimColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: spacingSm),
          Icon(icon, size: 16, color: color),
          const SizedBox(width: spacingSm),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.appTextPrimColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
