import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/motion.dart';

import '../application/quiz_use_cases.dart';
import '../domain/quiz_models.dart';
import '../infrastructure/quiz_service.dart';
import 'classic_game_screen.dart';
import 'clue_game_screen.dart';
import 'leaderboard_screen.dart';

/// Tab del quiz: una tarjeta por modo (clásico, audio, letra, portada y
/// emojis) con el estado del reto diario, acceso a práctica y estadísticas.
class QuizHomeScreen extends StatefulWidget {
  const QuizHomeScreen({super.key});

  @override
  State<QuizHomeScreen> createState() => _QuizHomeScreenState();
}

class _QuizHomeScreenState extends State<QuizHomeScreen> {
  static const _modeIcons = {
    QuizMode.classic: Icons.grid_view_rounded,
    QuizMode.audio: Icons.graphic_eq_rounded,
    QuizMode.lyrics: Icons.format_quote_rounded,
    QuizMode.cover: Icons.image_rounded,
    QuizMode.emoji: Icons.emoji_emotions_rounded,
  };

  final _service = QuizService();
  late final _getDaily = GetDailyQuizGameUseCase(_service);
  late final _getStats = GetQuizStatsUseCase(_service);

  /// Estado del reto diario por modo; si el modo no tiene canciones aún,
  /// su entrada guarda el mensaje de error en [_modeErrors].
  final Map<QuizMode, QuizGameState> _dailies = {};
  final Map<QuizMode, String> _modeErrors = {};
  QuizStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    // Un daily por modo, en paralelo; cada uno captura su propio error
    // (p. ej. emojis sin curar todavía no debe tumbar el resto)
    await Future.wait(QuizMode.values.map((mode) async {
      try {
        final state = await _getDaily(mode);
        _dailies[mode] = state;
        _modeErrors.remove(mode);
      } catch (e) {
        _dailies.remove(mode);
        _modeErrors[mode] = e.toString().replaceAll('Exception: ', '');
      }
    }));

    try {
      _stats = await _getStats();
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  void _open(QuizMode mode, {required bool practice}) {
    final screen = mode == QuizMode.classic
        ? ClassicGameScreen(practice: practice)
        : ClueGameScreen(mode: mode, practice: practice);
    Navigator.push(context, fadeThroughRoute(screen))
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _QuizSkeleton();
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(spacingMd),
        children: [
          // ── Cabecera ─────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.appAccentGlowColor,
                  borderRadius: BorderRadius.circular(radiusMd),
                ),
                child: const Icon(Icons.sports_esports_rounded,
                    color: appAccent, size: 22),
              ),
              const SizedBox(width: spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'quiz.title'.tr(),
                      style: TextStyle(
                        color: context.appTextPrimColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'quiz.subtitle'.tr(),
                      style: TextStyle(
                          color: context.appTextSecColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Acceso a la clasificación
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  fadeThroughRoute(const LeaderboardScreen()),
                ),
                icon: const Icon(Icons.leaderboard_rounded),
                color: context.appAccentColor,
                tooltip: 'quiz.lb_title'.tr(),
              ),
            ],
          ),
          const SizedBox(height: spacingLg),

          // ── Tarjetas de modo (entran en cascada) ─────────────────────────
          for (final (i, mode) in QuizMode.values.indexed) ...[
            AppEntrance(
              delay: Duration(milliseconds: i * 60),
              child: _ModeCard(
                icon: _modeIcons[mode]!,
                title: 'quiz.${mode.name}_title'.tr(),
                description: 'quiz.${mode.name}_desc'.tr(),
                daily: _dailies[mode],
                unavailableHint: _modeErrors[mode],
                onDaily: () => _open(mode, practice: false),
                onPractice: () => _open(mode, practice: true),
              ),
            ),
            const SizedBox(height: spacingMd),
          ],

          // ── Estadísticas ─────────────────────────────────────────────────
          if (_stats != null) ...[
            const SizedBox(height: spacingSm),
            Text(
              'quiz.stats_title'.tr(),
              style: TextStyle(
                color: context.appTextPrimColor,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: spacingSm),
            _StatsCard(stats: _stats!),
          ],
        ],
      ),
    );
  }
}

// ── Tarjeta de modo ───────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final QuizGameState? daily;
  final String? unavailableHint;
  final VoidCallback onDaily;
  final VoidCallback onPractice;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.daily,
    required this.unavailableHint,
    required this.onDaily,
    required this.onPractice,
  });

  @override
  Widget build(BuildContext context) {
    final d = daily;
    final available = d != null;

    return Container(
      padding: const EdgeInsets.all(spacingMd),
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: context.appDividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.appCard2Color,
                  borderRadius: BorderRadius.circular(radiusMd),
                ),
                child: Icon(icon, color: context.appTextSecColor, size: 22),
              ),
              const SizedBox(width: spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.appTextPrimColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                          color: context.appTextSecColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (available) _statusChip(context, d),
            ],
          ),
          const SizedBox(height: spacingMd),
          if (!available)
            Text(
              unavailableHint ?? 'quiz.mode_no_songs'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appTextDimColor, fontSize: 12),
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onDaily,
                    icon: const Icon(Icons.today_rounded, size: 16),
                    label: Text('quiz.daily'.tr(),
                        style: const TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: spacingSm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPractice,
                    icon: const Icon(Icons.all_inclusive_rounded, size: 16),
                    label: Text('quiz.practice'.tr(),
                        style: const TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _statusChip(BuildContext context, QuizGameState d) {
    final Color color;
    final String text;
    final IconData icon;

    if (d.solved) {
      color = appSuccess;
      text = 'quiz.daily_done'.tr();
      icon = Icons.check_circle_rounded;
    } else if (d.finished) {
      color = appError;
      text = 'quiz.daily_failed'.tr();
      icon = Icons.cancel_rounded;
    } else if (d.attemptsUsed > 0) {
      color = appAccent;
      text = 'quiz.attempts'.tr(args: ['${d.attemptsUsed}']);
      icon = Icons.pending_rounded;
    } else {
      color = context.appTextDimColor;
      text = 'quiz.daily_pending'.tr();
      icon = Icons.radio_button_unchecked_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Estadísticas ──────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final QuizStats stats;

  const _StatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    Widget row(QuizMode mode) {
      final daily = stats.daily[mode] ?? (played: 0, won: 0);
      final practice = stats.practice[mode] ?? (played: 0, won: 0);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                'quiz.${mode.name}_title'.tr(),
                style: TextStyle(
                  color: context.appTextPrimColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                '${'quiz.daily'.tr()}: ${daily.won}/${daily.played}',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: context.appTextSecColor, fontSize: 12),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                '${'quiz.practice'.tr()}: ${practice.won}/${practice.played}',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: context.appTextSecColor, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: spacingMd, vertical: spacingSm),
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: context.appDividerColor),
      ),
      child: Column(
        children: [
          for (final (i, mode) in QuizMode.values.indexed) ...[
            if (i > 0) Divider(height: 1, color: context.appDividerColor),
            row(mode),
          ],
        ],
      ),
    );
  }
}

// ── Skeleton de carga ─────────────────────────────────────────────────────────
// Silueta de la cabecera + las 5 tarjetas de modo mientras se cargan los retos.

class _QuizSkeleton extends StatelessWidget {
  const _QuizSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(spacingMd),
      children: [
        Row(
          children: [
            ShimmerBox(
                width: 40, height: 40, borderRadius: BorderRadius.circular(radiusMd)),
            const SizedBox(width: spacingSm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(width: 120, height: 16),
                SizedBox(height: 6),
                ShimmerBox(width: 180, height: 11),
              ],
            ),
          ],
        ),
        const SizedBox(height: spacingLg),
        ...List.generate(
          5,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: spacingMd),
            child: ShimmerBox(
                height: 112, borderRadius: BorderRadius.circular(radiusLg)),
          ),
        ),
      ],
    );
  }
}
