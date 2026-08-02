import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/motion.dart';
import 'package:viber/core/utils/haptics.dart';
import '../match_screen.dart';

/// Tarjeta de un reto de quiz dentro del chat (DM o grupo): muestra la info de
/// la partida y un botón "Unirse" que abre la sala de espera.
class QuizChallengeCard extends StatelessWidget {
  final int    matchId;
  final String? mode;
  final int?   totalRounds;
  final String fromLabel;
  final bool   isMine;

  const QuizChallengeCard({
    super.key,
    required this.matchId,
    required this.mode,
    required this.totalRounds,
    required this.fromLabel,
    required this.isMine,
  });

  String get _modeLabel => switch (mode) {
        'EMOJI'  => 'quiz.emoji_title'.tr(),
        'LYRICS' => 'quiz.lyrics_title'.tr(),
        'COVER'  => 'quiz.cover_title'.tr(),
        'AUDIO'  => 'quiz.audio_title'.tr(),
        _        => mode ?? '',
      };

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 6, left: isMine ? 40 : 0, right: isMine ? 0 : 40),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          gradient: appBrandGradient,
          borderRadius: BorderRadius.circular(radiusLg),
          boxShadow: [
            BoxShadow(
              color: appAccent.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(radiusMd),
                    ),
                    child: const Icon(Icons.sports_esports_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('quiz.duel_card_title'.tr(),
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                        Text('quiz.mode_rounds'.tr(namedArgs: {'mode': _modeLabel, 'rounds': '${totalRounds ?? '?'}'}),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(isMine ? 'quiz.you_challenged'.tr() : 'quiz.challenged_you'.tr(namedArgs: {'user': fromLabel}),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
              const SizedBox(height: 12),
              PressableScale(
                onTap: () {
                  Haptics.medium();
                  Navigator.push(context, fadeThroughRoute(MatchScreen(matchId: matchId)));
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(radiusMd),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow_rounded, color: appAccent, size: 20),
                      SizedBox(width: 4),
                      Text('common.join'.tr(),
                          style: TextStyle(color: appAccent, fontSize: 14, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
