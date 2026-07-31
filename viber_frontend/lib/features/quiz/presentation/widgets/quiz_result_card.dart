import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/user_avatar.dart';

/// Tarjeta de resultado de un duelo de quiz dentro del chat: muestra el ganador
/// y la puntuación, con un botón para ver la clasificación completa. La
/// clasificación viaja embebida en el mensaje, así que se conserva para siempre.
class QuizResultCard extends StatelessWidget {
  final String? winner;
  final List<dynamic>? standings;
  final String? myUsername;

  const QuizResultCard({
    super.key,
    required this.winner,
    required this.standings,
    required this.myUsername,
  });

  List<_Standing> get _rows => (standings ?? const [])
      .map((e) => _Standing.fromMap(e as Map))
      .toList()
    ..sort((a, b) => a.position.compareTo(b.position));

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final topScore = rows.isNotEmpty ? rows.first.score : 0;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(radiusLg),
          border: Border.all(color: appAccent.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: appAccentGlow,
                    borderRadius: BorderRadius.circular(radiusMd),
                  ),
                  child: const Icon(Icons.emoji_events_rounded, color: appAccent, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('quiz.duel_result'.tr(),
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 14, fontWeight: FontWeight.w800)),
                      Text(winner != null
                              ? 'Ganó $winner · $topScore pts'
                              : 'Sin ganador',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Vista previa: top 3
            ...rows.take(3).map((r) => _miniRow(context, r)),
            if (rows.length > 3) ...[
              const SizedBox(height: 4),
              Text('quiz.and_more'.tr(namedArgs: {'n': '${rows.length - 3}'}),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 11)),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openFull(context, rows),
                icon: const Icon(Icons.leaderboard_rounded, size: 16),
                label: Text('quiz.view_ranking'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: appAccent,
                  side: const BorderSide(color: appAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniRow(BuildContext context, _Standing r) {
    final isMe = r.username == myUsername;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: r.position == 1
                ? const Icon(Icons.emoji_events_rounded, color: appAccent, size: 15)
                : Text('${r.position}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(isMe ? '${r.username} (tú)' : r.username,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13, fontWeight: isMe ? FontWeight.w700 : FontWeight.w500)),
          ),
          Text('${r.score}',
              style: const TextStyle(color: appAccent, fontSize: 13, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  void _openFull(BuildContext context, List<_Standing> rows) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final bottomPad = MediaQuery.of(context).padding.bottom;
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(0, 14, 0, bottomPad + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  const Icon(Icons.emoji_events_rounded, color: appAccent, size: 20),
                  const SizedBox(width: 8),
                  Text('quiz.final_ranking'.tr(),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: rows.map((r) {
                    final isMe = r.username == myUsername;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe ? appAccentDim : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(radiusMd),
                        border: Border.all(
                            color: r.position == 1 ? appAccent.withValues(alpha: 0.5) : appDivider),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 22,
                            child: r.position == 1
                                ? const Icon(Icons.emoji_events_rounded, color: appAccent, size: 18)
                                : Text('${r.position}',
                                    style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                        fontSize: 14, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 10),
                          UserAvatar(username: r.username, avatarUrl: null, radius: 14),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(isMe ? '${r.username} (tú)' : r.username,
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                          ),
                          Text('${r.score}',
                              style: const TextStyle(
                                  color: appAccent, fontSize: 15, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 2),
                          Text('quiz.lb_pts'.tr(),
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                                  fontSize: 10)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Standing {
  final int position;
  final String username;
  final int score;
  final int correctCount;
  const _Standing(this.position, this.username, this.score, this.correctCount);

  factory _Standing.fromMap(Map m) => _Standing(
        (m['position'] as num?)?.toInt() ?? 0,
        m['username'] as String? ?? '',
        (m['score'] as num?)?.toInt() ?? 0,
        (m['correctCount'] as num?)?.toInt() ?? 0,
      );
}
