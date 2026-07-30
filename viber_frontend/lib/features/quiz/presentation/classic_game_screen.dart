import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/utils/haptics.dart';
import 'package:viber/core/widgets/app_image.dart';
import 'package:viber/core/widgets/app_snack_bar.dart';

import '../application/quiz_use_cases.dart';
import '../domain/quiz_models.dart';
import '../infrastructure/quiz_service.dart';
import 'widgets/guess_board.dart';
import 'widgets/quiz_result_panel.dart';
import 'widgets/song_autocomplete_field.dart';

/// Modo clásico (tipo LoLdle): intentos ilimitados y casillas de comparación.
/// Pistas extra: portada tras 5 fallos, inicial del título tras 8.
class ClassicGameScreen extends StatefulWidget {
  /// true → partida de práctica (canción aleatoria); false → reto diario.
  final bool practice;

  const ClassicGameScreen({super.key, required this.practice});

  @override
  State<ClassicGameScreen> createState() => _ClassicGameScreenState();
}

class _ClassicGameScreenState extends State<ClassicGameScreen> {
  final _service = QuizService();
  late final _getDaily = GetDailyQuizGameUseCase(_service);
  late final _newPractice = NewPracticeQuizGameUseCase(_service);
  late final _guess = GuessQuizSongUseCase(_service);
  late final _surrender = SurrenderQuizGameUseCase(_service);

  QuizGameState? _state;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  /// Nº del intento recién enviado: el tablero anima esa fila (acierto/fallo).
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
    });
    try {
      final state = widget.practice
          ? await _newPractice(QuizMode.classic)
          : await _getDaily(QuizMode.classic);
      if (mounted) setState(() => _state = state);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onGuess(QuizPoolSong song) async {
    final state = _state;
    if (state == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      final updated = await _guess(state.gameId, song.id);
      if (mounted) {
        setState(() {
          _state = updated;
          _reactAttempt = updated.guesses.length;
        });
        if (updated.guesses.isNotEmpty) {
          if (updated.guesses.last.correct) {
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

  Future<void> _onSurrender() async {
    final state = _state;
    if (state == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('quiz.give_up'.tr()),
        content: Text('quiz.give_up_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('quiz.give_up'.tr()),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final updated = await _surrender(state.gameId);
      if (mounted) setState(() => _state = updated);
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context,
            e.toString().replaceAll('Exception: ', ''), error: true);
      }
    }
  }

  void _showCoverHint(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radiusLg),
          child: AppImage(url: url, width: 280, height: 280),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.practice
              ? '${'quiz.classic_title'.tr()} — ${'quiz.practice'.tr()}'
              : '${'quiz.classic_title'.tr()} — ${'quiz.daily'.tr()}',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : _buildGame(),
    );
  }

  Widget _buildGame() {
    final state = _state!;
    final guessedIds =
        state.guesses.map((g) => g.song?.id).whereType<int>().toSet();

    return ListView(
      padding: const EdgeInsets.all(spacingMd),
      children: [
        // ── Cabecera: intentos y aciertos globales ───────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _infoChip(
              Icons.tag_rounded,
              'quiz.attempts'.tr(args: ['${state.attemptsUsed}']),
            ),
            if (!state.practice && state.dailySolvedCount != null) ...[
              const SizedBox(width: spacingSm),
              _infoChip(
                Icons.emoji_events_outlined,
                'quiz.solved_today'.tr(args: ['${state.dailySolvedCount}']),
              ),
            ],
          ],
        ),
        const SizedBox(height: spacingMd),

        // ── Pistas ───────────────────────────────────────────────────────────
        if (!state.finished && state.hints != null) ...[
          _HintsRow(
            hints: state.hints!,
            attempts: state.attemptsUsed,
            onShowCover: _showCoverHint,
          ),
          const SizedBox(height: spacingMd),
        ],

        // ── Buscador ─────────────────────────────────────────────────────────
        if (!state.finished)
          SongAutocompleteField(
            mode: QuizMode.classic,
            enabled: !_submitting,
            excludedIds: guessedIds,
            onSelected: _onGuess,
          ),

        if (state.finished) ...[
          QuizResultPanel(
            state: state,
            onPlayAgain: widget.practice ? _load : null,
          ),
        ],

        const SizedBox(height: spacingMd),
        if (state.guesses.isNotEmpty) ...[
          const QuizLegend(),
          const SizedBox(height: spacingMd),
          ClassicGuessBoard(
              guesses: state.guesses, reactAttempt: _reactAttempt),
        ] else if (!state.finished)
          Padding(
            padding: const EdgeInsets.only(top: spacingXl),
            child: Column(
              children: [
                Icon(Icons.music_note_rounded,
                    size: 48, color: context.appTextDimColor),
                const SizedBox(height: spacingSm),
                Text(
                  'quiz.classic_empty'.tr(),
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: context.appTextSecColor, fontSize: 13),
                ),
              ],
            ),
          ),

        // ── Rendirse ─────────────────────────────────────────────────────────
        if (!state.finished && state.attemptsUsed > 0)
          TextButton.icon(
            onPressed: _onSurrender,
            icon: const Icon(Icons.flag_outlined, size: 16, color: appError),
            label: Text(
              'quiz.give_up'.tr(),
              style: const TextStyle(color: appError, fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: spacingSm, vertical: 5),
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(radiusFull),
        border: Border.all(color: context.appDividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: context.appTextSecColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(color: context.appTextSecColor, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Pistas: portada y título ──────────────────────────────────────────────────

class _HintsRow extends StatelessWidget {
  final QuizHints hints;
  final int attempts;
  final void Function(String coverUrl) onShowCover;

  const _HintsRow({
    required this.hints,
    required this.attempts,
    required this.onShowCover,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _hintChip(
            context,
            icon: Icons.image_outlined,
            unlocked: hints.coverUrl != null,
            lockedText: 'quiz.hint_cover_locked'
                .tr(args: ['${hints.coverUnlockAt - attempts}']),
            unlockedText: 'quiz.hint_cover'.tr(),
            onTap: hints.coverUrl != null
                ? () => onShowCover(hints.coverUrl!)
                : null,
          ),
        ),
        const SizedBox(width: spacingSm),
        Expanded(
          child: _hintChip(
            context,
            icon: Icons.abc_rounded,
            unlocked: hints.titleHint != null,
            lockedText: 'quiz.hint_title_locked'
                .tr(args: ['${hints.titleUnlockAt - attempts}']),
            unlockedText: hints.titleHint ?? '',
          ),
        ),
      ],
    );
  }

  Widget _hintChip(
    BuildContext context, {
    required IconData icon,
    required bool unlocked,
    required String lockedText,
    required String unlockedText,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: spacingSm, vertical: spacingSm),
        decoration: BoxDecoration(
          color: unlocked
              ? context.appAccentGlowColor
              : context.appCardColor,
          borderRadius: BorderRadius.circular(radiusMd),
          border: Border.all(
            color: unlocked
                ? appAccent.withValues(alpha: 0.4)
                : context.appDividerColor,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              unlocked ? icon : Icons.lock_outline_rounded,
              size: 14,
              color: unlocked ? appAccent : context.appTextDimColor,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                unlocked ? unlockedText : lockedText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                      unlocked ? appAccent : context.appTextSecColor,
                  fontSize: 11.5,
                  fontWeight:
                      unlocked ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error con reintento ───────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
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
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appTextSecColor, fontSize: 14),
            ),
            const SizedBox(height: spacingMd),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('common.refresh'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
