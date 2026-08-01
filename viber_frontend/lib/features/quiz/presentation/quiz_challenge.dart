import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/app_snack_bar.dart';
import 'package:viber/core/widgets/motion.dart';
import '../infrastructure/quiz_match_service.dart';
import 'match_screen.dart';

/// Lanza el flujo de "reto de quiz" desde un chat: hoja de configuración
/// (modo / rondas / segundos) → crea la partida → abre la sala de espera.
///
/// scope = "DM" (con [otherUsername]) o "GROUP" (con [groupId]).
Future<void> startQuizChallenge(
  BuildContext context, {
  required String scope,
  String? otherUsername,
  int?    groupId,
}) async {
  final config = await showModalBottomSheet<_ChallengeConfig>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ChallengeSheet(),
  );
  if (config == null) return;
  if (!context.mounted) return;

  try {
    final matchId = await QuizMatchService().createMatch(
      mode: config.mode,
      scope: scope,
      otherUsername: otherUsername,
      groupId: groupId,
      totalRounds: config.rounds,
      secondsPerRound: config.seconds,
    );
    if (!context.mounted) return;
    Navigator.push(context, fadeThroughRoute(
      MatchScreen(matchId: matchId, autoStartHost: true)));
  } catch (e) {
    if (context.mounted) {
      AppSnackBar.show(context, e.toString().replaceAll('Exception: ', ''), error: true);
    }
  }
}

class _ChallengeConfig {
  final String mode;
  final int rounds;
  final int seconds;
  const _ChallengeConfig(this.mode, this.rounds, this.seconds);
}

class _ChallengeSheet extends StatefulWidget {
  const _ChallengeSheet();

  @override
  State<_ChallengeSheet> createState() => _ChallengeSheetState();
}

class _ChallengeSheetState extends State<_ChallengeSheet> {
  // Modos en vivo: la pista la renderiza el cliente (emoji/letra/portada como
  // texto o imagen, y audio por proxy para no delatar la canción).
  // Getter y no `static const`: las etiquetas se traducen con .tr() y hay que
  // reevaluarlas, porque una constante las congelaría al idioma del arranque.
  static List<(String, String, IconData)> get _modes => [
    ('EMOJI',  'quiz.emoji_title'.tr(),  Icons.emoji_emotions_outlined),
    ('LYRICS', 'quiz.lyrics_title'.tr(), Icons.lyrics_outlined),
    ('COVER',  'quiz.cover_title'.tr(),  Icons.album_outlined),
    ('AUDIO',  'quiz.audio_title'.tr(),  Icons.music_note_outlined),
  ];

  String _mode = 'EMOJI';
  int _rounds = 5;
  int _seconds = 15;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, bottomPad + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.sports_esports_rounded, color: appAccent, size: 20),
              const SizedBox(width: 8),
              Text('quiz.challenge_title'.tr(),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),

          _sectionLabel('MODO'),
          const SizedBox(height: 8),
          Row(
            children: _modes.map((m) {
              final selected = _mode == m.$1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _mode = m.$1),
                    borderRadius: BorderRadius.circular(radiusMd),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: selected ? appAccentGlow : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(radiusMd),
                        border: Border.all(color: selected ? appAccent : appDivider),
                      ),
                      child: Column(
                        children: [
                          Icon(m.$3, color: selected ? appAccent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), size: 22),
                          const SizedBox(height: 6),
                          Text(m.$2,
                              style: TextStyle(
                                  color: selected ? appAccent : Theme.of(context).colorScheme.onSurface,
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          _stepperRow('quiz.rounds_label'.tr(), _rounds, 3, 10, (v) => setState(() => _rounds = v)),
          const SizedBox(height: 10),
          _stepperRow('quiz.seconds_per_round'.tr(), _seconds, 5, 30, (v) => setState(() => _seconds = v), step: 5),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, _ChallengeConfig(_mode, _rounds, _seconds)),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text('quiz.start_match'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: appAccent, foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1));

  Widget _stepperRow(String label, int value, int min, int max,
      ValueChanged<int> onChanged, {int step = 1}) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
        ),
        _roundIcon(Icons.remove_rounded, value > min
            ? () => onChanged((value - step).clamp(min, max)) : null),
        SizedBox(
          width: 38,
          child: Text('$value', textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        _roundIcon(Icons.add_rounded, value < max
            ? () => onChanged((value + step).clamp(min, max)) : null),
      ],
    );
  }

  Widget _roundIcon(IconData icon, VoidCallback? onTap) {
    return Material(
      color: onTap == null ? Theme.of(context).colorScheme.surface : appAccentGlow,
      borderRadius: BorderRadius.circular(radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radiusSm),
        child: SizedBox(width: 34, height: 34,
            child: Icon(icon, size: 18,
                color: onTap == null
                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3) : appAccent)),
      ),
    );
  }
}
