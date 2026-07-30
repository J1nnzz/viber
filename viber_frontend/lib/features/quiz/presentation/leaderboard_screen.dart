import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/user_avatar.dart';

import '../application/quiz_use_cases.dart';
import '../domain/leaderboard_models.dart';
import '../infrastructure/quiz_service.dart';
import 'widgets/scoring_info_sheet.dart';

/// Clasificación del quiz. Dos ejes que el usuario alterna con segmentos:
///  - ámbito:  Mundial / Amigos
///  - periodo: Diario (tablero "en directo") / Mes (clasificación del periodo)
///
/// Solo puntúa el reto diario. La fila del propio usuario queda fijada abajo
/// con su racha aunque esté fuera del top mostrado.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _service = QuizService();
  late final _getLeaderboard = GetQuizLeaderboardUseCase(_service);

  LeaderboardScope _scope = LeaderboardScope.world;
  LeaderboardPeriod _period = LeaderboardPeriod.daily;

  Leaderboard? _data;
  bool _loading = true;
  String? _error;

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
      final data = await _getLeaderboard(_scope, _period);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _setScope(LeaderboardScope scope) {
    if (scope == _scope) return;
    setState(() => _scope = scope);
    _load();
  }

  void _setPeriod(LeaderboardPeriod period) {
    if (period == _period) return;
    setState(() => _period = period);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('quiz.lb_title'.tr()),
        actions: [
          IconButton(
            onPressed: () => ScoringInfoSheet.show(context),
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'quiz.score_title'.tr(),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Controles ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  spacingMd, spacingMd, spacingMd, spacingSm),
              child: Column(
                children: [
                  _Segmented(
                    options: [
                      _SegOption('quiz.lb_world'.tr(), Icons.public_rounded,
                          _scope == LeaderboardScope.world,
                          () => _setScope(LeaderboardScope.world)),
                      _SegOption('quiz.lb_friends'.tr(), Icons.group_rounded,
                          _scope == LeaderboardScope.friends,
                          () => _setScope(LeaderboardScope.friends)),
                    ],
                  ),
                  const SizedBox(height: spacingSm),
                  _Segmented(
                    options: [
                      _SegOption('quiz.lb_daily'.tr(), Icons.today_rounded,
                          _period == LeaderboardPeriod.daily,
                          () => _setPeriod(LeaderboardPeriod.daily)),
                      _SegOption('quiz.lb_month'.tr(),
                          Icons.calendar_month_rounded,
                          _period == LeaderboardPeriod.month,
                          () => _setPeriod(LeaderboardPeriod.month)),
                    ],
                  ),
                  // Indicador "en directo" del tablero diario (rol coral).
                  if (_period == LeaderboardPeriod.daily) ...[
                    const SizedBox(height: spacingSm),
                    const _LiveBadge(),
                  ],
                ],
              ),
            ),

            // ── Cuerpo ───────────────────────────────────────────────────────
            Expanded(child: _buildBody()),

            // ── Fila propia fijada ───────────────────────────────────────────
            if (_data != null) _MeCard(me: _data!.me, period: _period),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _CenteredHint(
        icon: Icons.error_outline_rounded,
        text: _error!,
        action: TextButton(
          onPressed: _load,
          child: Text('quiz.lb_retry'.tr()),
        ),
      );
    }
    final entries = _data?.entries ?? [];
    if (entries.isEmpty) {
      return _CenteredHint(
        icon: Icons.emoji_events_outlined,
        text: _scope == LeaderboardScope.friends
            ? 'quiz.lb_empty_friends'.tr()
            : 'quiz.lb_empty'.tr(),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
            spacingMd, spacingXs, spacingMd, spacingMd),
        itemCount: entries.length,
        itemBuilder: (_, i) => _LeaderboardTile(row: entries[i]),
      ),
    );
  }
}

// ── Segmentos (toggle) ─────────────────────────────────────────────────────────

class _SegOption {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  _SegOption(this.label, this.icon, this.selected, this.onTap);
}

class _Segmented extends StatelessWidget {
  final List<_SegOption> options;
  const _Segmented({required this.options});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.appCard2Color,
        borderRadius: BorderRadius.circular(radiusFull),
      ),
      child: Row(
        children: options.map((o) {
          // Activo = acento morado (rol "seleccionado"); inactivo = neutro.
          final fg = o.selected ? context.appOnAccentColor : context.appTextSecColor;
          return Expanded(
            child: GestureDetector(
              onTap: o.onTap,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: o.selected
                      ? context.appAccentColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(radiusFull),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(o.icon, size: 15, color: fg),
                    const SizedBox(width: 6),
                    Text(
                      o.label,
                      style: TextStyle(
                        color: fg,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// "● en directo" — el tablero diario se mueve hasta que todos completan sus
/// modos. Coral, el rol de marca para actividad/directo.
class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: appEnergy,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: appEnergy.withValues(alpha: 0.6),
                  blurRadius: 6,
                  spreadRadius: 1),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'quiz.lb_live'.tr(),
          style: const TextStyle(
            color: appEnergy,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

// ── Fila de la tabla ────────────────────────────────────────────────────────────

class _LeaderboardTile extends StatelessWidget {
  final LeaderboardRow row;
  const _LeaderboardTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final isMe = row.isMe;
    return Container(
      margin: const EdgeInsets.only(bottom: spacingSm),
      padding: const EdgeInsets.symmetric(
          horizontal: spacingSm, vertical: spacingSm),
      decoration: BoxDecoration(
        color: isMe ? context.appAccentDimColor : context.appCardColor,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(
          color: isMe ? context.appAccentColor : context.appDividerColor,
          width: isMe ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 34, child: _RankBadge(rank: row.rank)),
          const SizedBox(width: spacingXs),
          UserAvatar(
              username: row.username, avatarUrl: row.avatarUrl, radius: 18),
          const SizedBox(width: spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        row.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.appTextPrimColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Text(
                        'quiz.lb_you'.tr(),
                        style: TextStyle(
                          color: context.appAccentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  'quiz.lb_solved_n'.tr(args: ['${row.solvedCount}']),
                  style: TextStyle(
                      color: context.appTextSecColor, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: spacingSm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${row.points}',
                style: TextStyle(
                  color: context.appAccentColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'quiz.lb_pts'.tr(),
                style:
                    TextStyle(color: context.appTextDimColor, fontSize: 10.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Medalla (icono) para el podio; número para el resto.
class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  // Colores de medalla del podio: oro / plata / bronce.
  static const _medalColors = {
    1: Color(0xFFF5B945),
    2: Color(0xFFB8C2CC),
    3: Color(0xFFCD7F4D),
  };

  @override
  Widget build(BuildContext context) {
    final medal = _medalColors[rank];
    if (medal != null) {
      return Center(
        child: Icon(Icons.military_tech_rounded, color: medal, size: 24),
      );
    }
    return Center(
      child: Text(
        '$rank',
        style: TextStyle(
          color: context.appTextSecColor,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Fila propia fijada ──────────────────────────────────────────────────────────

class _MeCard extends StatelessWidget {
  final LeaderboardMe me;
  final LeaderboardPeriod period;
  const _MeCard({required this.me, required this.period});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          spacingMd, spacingSm, spacingMd, spacingMd),
      decoration: BoxDecoration(
        color: context.appSurfaceColor,
        border: Border(top: BorderSide(color: context.appDividerColor)),
      ),
      child: me.ranked
          ? Row(
              children: [
                _stat(
                  context,
                  label: 'quiz.lb_position'.tr(),
                  value: me.rank != null ? '#${me.rank}' : '—',
                ),
                _divider(context),
                _stat(
                  context,
                  label: 'quiz.lb_pts'.tr(),
                  value: '${me.points}',
                  highlight: true,
                ),
                _divider(context),
                _stat(
                  context,
                  label: 'quiz.lb_streak'.tr(),
                  value: '${me.currentStreak}',
                  icon: Icons.local_fire_department_rounded,
                  energy: true,
                ),
              ],
            )
          : Row(
              children: [
                Icon(Icons.emoji_events_outlined,
                    size: 18, color: context.appTextSecColor),
                const SizedBox(width: spacingSm),
                Expanded(
                  child: Text(
                    'quiz.lb_join'.tr(),
                    style: TextStyle(
                        color: context.appTextSecColor, fontSize: 12.5),
                  ),
                ),
                if (me.currentStreak > 0) ...[
                  const Icon(Icons.local_fire_department_rounded,
                      color: appEnergy, size: 16),
                  const SizedBox(width: 3),
                  Text('${me.currentStreak}',
                      style: const TextStyle(
                          color: appEnergy,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ],
              ],
            ),
    );
  }

  Widget _stat(BuildContext context,
      {required String label,
      required String value,
      IconData? icon,
      bool highlight = false,
      bool energy = false}) {
    final color = energy
        ? appEnergy
        : highlight
            ? context.appAccentColor
            : context.appTextPrimColor;
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: color, size: 17),
                const SizedBox(width: 4),
              ],
              Text(
                value,
                style: TextStyle(
                    color: color, fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: context.appTextSecColor, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) => Container(
        width: 1,
        height: 30,
        color: context.appDividerColor,
      );
}

// ── Estado vacío / error ────────────────────────────────────────────────────────

class _CenteredHint extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;
  const _CenteredHint({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: context.appTextDimColor),
            const SizedBox(height: spacingMd),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appTextSecColor, fontSize: 13.5),
            ),
            if (action != null) ...[
              const SizedBox(height: spacingSm),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
