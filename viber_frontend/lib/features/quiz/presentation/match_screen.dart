import 'package:easy_localization/easy_localization.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:viber/core/constants/api_constants.dart';
import 'package:viber/core/services/notification_service.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/utils/haptics.dart';
import 'package:viber/core/widgets/motion.dart';
import 'package:viber/core/widgets/user_avatar.dart';
import '../../auth/infrastructure/auth_service.dart';
import '../domain/match_models.dart';
import '../infrastructure/quiz_match_socket.dart';
import 'widgets/match_audio_clue.dart';

/// Pantalla de una partida de quiz EN VIVO. Estado dirigido por los eventos STOMP:
/// sala de espera → rondas (pista + 4 opciones + anillo de tiempo) → revelación
/// con marcador y cuenta atrás a la siguiente → podio final. Con feedback háptico,
/// sonidos y animaciones en los momentos clave.
class MatchScreen extends StatefulWidget {
  final int  matchId;
  final bool autoStartHost;
  const MatchScreen({super.key, required this.matchId, this.autoStartHost = false});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

enum _Phase { connecting, lobby, question, reveal, finished }

class _MatchScreenState extends State<MatchScreen>
    with SingleTickerProviderStateMixin {
  final _auth = AuthService();
  QuizMatchSocket? _socket;
  String? _myUsername;
  String? _token;

  _Phase _phase = _Phase.connecting;

  LobbyState?    _lobby;
  QuestionEvent? _question;
  RevealEvent?   _reveal;
  FinalEvent?    _finalResult;

  int? _myPick;
  int  _secondsLeft = 0;
  int  _nextCountdown = 0;
  Timer? _ticker;

  // Anillo de tiempo de la ronda (animación suave independiente del contador)
  late final AnimationController _ringCtrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 1));

  @override
  void initState() {
    super.initState();
    // Al abrir el duelo, descartar el aviso flotante de "te reta a un duelo".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    });
    _init();
  }

  Future<void> _init() async {
    final token = await _auth.getToken();
    if (token == null) return;
    _token        = token;
    final parts   = token.split('.');
    final decoded = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    _myUsername   = (jsonDecode(decoded) as Map<String, dynamic>)['sub'] as String?;

    _socket = QuizMatchSocket(matchId: widget.matchId, token: token)
      ..onLobby    = _onLobby
      ..onQuestion = _onQuestion
      ..onReveal   = _onReveal
      ..onFinal    = _onFinal
      ..onConnected = () { _socket?.join(); }
      ..connect();
  }

  // ── Eventos ─────────────────────────────────────────────────────────────────

  void _onLobby(LobbyState lobby) {
    if (!mounted) return;
    setState(() { _lobby = lobby; if (_phase == _Phase.connecting) _phase = _Phase.lobby; });
  }

  void _onQuestion(QuestionEvent q) {
    if (!mounted) return;
    _ticker?.cancel();
    setState(() {
      _question = q;
      _reveal   = null;
      _myPick   = null;
      _phase    = _Phase.question;
      _secondsLeft = q.secondsLeft;
    });
    _ringCtrl
      ..stop()
      ..duration = Duration(seconds: q.secondsLeft <= 0 ? 1 : q.secondsLeft)
      ..forward(from: 0.0);
    _startTicker();
  }

  void _onReveal(RevealEvent r) {
    if (!mounted) return;
    _ticker?.cancel();
    _ringCtrl.stop();
    final iWasRight = r.correctOptionId == _myPick;
    if (_myPick != null) {
      if (iWasRight) { Haptics.success(); NotificationService.playNotificationSound(); }
      else            { Haptics.error(); }
    }
    setState(() {
      _reveal = r;
      _phase = _Phase.reveal;
      _nextCountdown = r.nextInSeconds;
    });
    _startTicker();
  }

  void _onFinal(FinalEvent f) {
    if (!mounted) return;
    _ticker?.cancel();
    if (f.winner == _myUsername) { Haptics.success(); NotificationService.playNotificationSound(); }
    setState(() { _finalResult = f; _phase = _Phase.finished; });
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_phase == _Phase.question) {
          _secondsLeft = (_secondsLeft - 1).clamp(0, 60);
          if (_secondsLeft > 0 && _secondsLeft <= 3) SystemSound.play(SystemSoundType.click);
          if (_secondsLeft == 0) t.cancel();
        } else if (_phase == _Phase.reveal) {
          _nextCountdown = (_nextCountdown - 1).clamp(0, 60);
          if (_nextCountdown == 0) t.cancel();
        } else {
          t.cancel();
        }
      });
    });
  }

  void _answer(int optionId) {
    if (_myPick != null) return;
    Haptics.selection();
    setState(() => _myPick = optionId);
    _socket?.answer(optionId);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ringCtrl.dispose();
    _socket?.leave();
    _socket?.disconnect();
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('quiz.match_title'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: switch (_phase) {
        _Phase.connecting => const Center(child: CircularProgressIndicator(color: appAccent)),
        _Phase.lobby      => _buildLobby(),
        _Phase.question   => _buildQuestion(),
        _Phase.reveal     => _buildReveal(),
        _Phase.finished   => _buildFinal(),
      },
    );
  }

  // ── Lobby ───────────────────────────────────────────────────────────────────

  Widget _buildLobby() {
    final lobby = _lobby;
    if (lobby == null) {
      return const Center(child: CircularProgressIndicator(color: appAccent));
    }
    final amHost = lobby.host == _myUsername;
    final canStart = amHost && lobby.players.length >= 2;

    return Padding(
      padding: const EdgeInsets.all(spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: spacingMd),
          const Icon(Icons.sports_esports_rounded, color: appAccent, size: 48),
          const SizedBox(height: spacingMd),
          Text('quiz.lobby_title'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('quiz.match_mode_line'.tr(namedArgs: {'mode': '${_modeLabel(lobby.mode)}', 'rounds': '${lobby.totalRounds}', 'seconds': '${lobby.secondsPerRound}'}),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 13)),
          const SizedBox(height: spacingLg),
          Text('quiz.players_count'.tr(namedArgs: {'n': '${lobby.players.length}'}),
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
          const SizedBox(height: spacingSm),
          Expanded(
            child: ListView(
              children: lobby.players.indexed.map((e) => AppEntrance(
                delay: Duration(milliseconds: e.$1 * 60),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(radiusMd),
                    border: Border.all(color: appDivider),
                  ),
                  child: Row(
                    children: [
                      UserAvatar(username: e.$2, avatarUrl: null, radius: 16),
                      const SizedBox(width: 10),
                      Text(e.$2 == _myUsername ? 'groups.member_you'.tr(namedArgs: {'name': '${e.$2}'}) : e.$2,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      if (e.$2 == lobby.host)
                        const Icon(Icons.star_rounded, color: appAccent, size: 18),
                    ],
                  ),
                ),
              )).toList(),
            ),
          ),
          if (amHost)
            PressableScale(
              onTap: canStart ? () { Haptics.medium(); _socket?.start(); } : null,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: canStart ? appAccent : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(radiusMd),
                  border: canStart ? null : Border.all(color: appDivider),
                ),
                child: Center(
                  child: Text(canStart ? 'quiz.start_match'.tr() : 'quiz.waiting_players'.tr(),
                      style: TextStyle(
                          color: canStart ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            )
          else
            Text('quiz.waiting_host'.tr(namedArgs: {'host': '${lobby.host}'}),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 13)),
        ],
      ),
    );
  }

  // ── Pregunta ────────────────────────────────────────────────────────────────

  Widget _buildQuestion() {
    final q = _question!;
    return Padding(
      padding: const EdgeInsets.all(spacingLg),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('quiz.round_of'.tr(namedArgs: {'n': '${q.round}', 'total': '${q.totalRounds}'}),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 14, fontWeight: FontWeight.w600)),
              _timerRing(),
            ],
          ),
          const SizedBox(height: spacingMd),
          Expanded(
            child: Center(
              child: AppEntrance(
                key: ValueKey('clue_${q.round}'),
                child: _buildClue(q),
              ),
            ),
          ),
          const SizedBox(height: spacingSm),
          AnimatedOpacity(
            opacity: _myPick != null ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Text('quiz.answer_sent'.tr(),
                style: TextStyle(color: appAccent, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: spacingSm),
          _optionsGrid(q.options),
        ],
      ),
    );
  }

  Widget _buildClue(QuestionEvent q) {
    if (q.clueImageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radiusLg),
        child: Image.network(q.clueImageUrl!, width: 200, height: 200, fit: BoxFit.cover),
      );
    }
    if (q.clueAudio) {
      if (_token == null) {
        return const Icon(Icons.music_note_rounded, color: appAccent, size: 90);
      }
      return MatchAudioClue(
        key: ValueKey('audio_${q.round}'),
        audioUrl: '${ApiConstants.quizUrl}/match/${widget.matchId}/audio?token=$_token',
      );
    }
    final isEmoji = q.mode == 'EMOJI';
    return Container(
      padding: const EdgeInsets.all(spacingLg),
      decoration: BoxDecoration(
        color: appAccentGlow,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: appDivider),
      ),
      child: Text(
        q.clueText ?? '',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: isEmoji ? 40 : 18,
          height: 1.4,
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: isEmoji ? FontWeight.w400 : FontWeight.w600,
          fontStyle: isEmoji ? FontStyle.normal : FontStyle.italic,
        ),
      ),
    );
  }

  /// Rejilla 2×2 SIEMPRE visible (alturas fijas, no se recorta).
  Widget _optionsGrid(List<MatchOption> opts) {
    Widget cell(int i) => Expanded(
      child: i < opts.length
          ? _optionButton(opts[i], _letter(i))
          : const SizedBox.shrink(),
    );
    Widget row(int a, int b) => SizedBox(
      height: 78,
      child: Row(children: [cell(a), const SizedBox(width: 10), cell(b)]),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [row(0, 1), const SizedBox(height: 10), row(2, 3)],
    );
  }

  Widget _optionButton(MatchOption o, String letter) {
    final answered = _myPick != null;
    final reveal   = _reveal;
    Color bg     = Theme.of(context).colorScheme.surface;
    Color border = appDivider;
    Color badge  = appAccentGlow;
    Color badgeFg = appAccent;

    if (reveal != null) {
      if (o.id == reveal.correctOptionId) {
        bg = appSuccess.withValues(alpha: 0.18); border = appSuccess; badge = appSuccess; badgeFg = Colors.white;
      } else if (o.id == _myPick) {
        bg = appError.withValues(alpha: 0.15); border = appError; badge = appError; badgeFg = Colors.white;
      }
    } else if (o.id == _myPick) {
      bg = appAccentGlow; border = appAccent;
    }

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: border, width: 1.6),
      ),
      child: Row(
        children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(color: badge, borderRadius: BorderRadius.circular(radiusSm)),
            alignment: Alignment.center,
            child: Text(letter, style: TextStyle(color: badgeFg, fontSize: 13, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13, fontWeight: FontWeight.w700, height: 1.1)),
                Text(o.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );

    // Resaltado de la correcta en la revelación con un "pop".
    if (reveal != null && o.id == reveal.correctOptionId) {
      return FeedbackEntrance(
        key: ValueKey('correct_${reveal.round}_${o.id}'),
        kind: FeedbackKind.success,
        child: content,
      );
    }
    return PressableScale(
      onTap: answered ? null : () => _answer(o.id),
      child: content,
    );
  }

  Widget _timerRing() {
    return SizedBox(
      width: 50, height: 50,
      child: AnimatedBuilder(
        animation: _ringCtrl,
        builder: (_, __) {
          final remaining = (1 - _ringCtrl.value).clamp(0.0, 1.0);
          final danger = _secondsLeft <= 3;
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 48, height: 48,
                child: CircularProgressIndicator(
                  value: remaining,
                  strokeWidth: 4,
                  backgroundColor: appAccentGlow,
                  valueColor: AlwaysStoppedAnimation(danger ? appError : appAccent),
                ),
              ),
              Text('$_secondsLeft',
                  style: TextStyle(
                      color: danger ? appError : Theme.of(context).colorScheme.onSurface,
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          );
        },
      ),
    );
  }

  // ── Revelación ──────────────────────────────────────────────────────────────

  Widget _buildReveal() {
    final r = _reveal!;
    final iWasRight = r.correctOptionId == _myPick;
    return Padding(
      padding: const EdgeInsets.all(spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: spacingSm),
          FeedbackEntrance(
            key: ValueKey('feedback_${r.round}'),
            kind: iWasRight ? FeedbackKind.success : FeedbackKind.error,
            child: Icon(iWasRight ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: iWasRight ? appSuccess : appError, size: 48),
          ),
          const SizedBox(height: spacingSm),
          Text(iWasRight ? 'quiz.correct'.tr() : (_myPick == null ? 'quiz.no_answer'.tr() : 'quiz.you_failed'.tr()),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: spacingXs),
          Text('${r.correctTitle} · ${r.correctArtist}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: appAccent, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: spacingMd),
          _nextCountdownChip(r),
          const SizedBox(height: spacingMd),
          Text('quiz.scoreboard'.tr(),
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
          const SizedBox(height: spacingSm),
          Expanded(child: _scoreboard(r.scoreboard)),
        ],
      ),
    );
  }

  Widget _nextCountdownChip(RevealEvent r) {
    final label = r.last ? 'quiz.results_in'.tr() : 'quiz.next_round_in'.tr();
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: appAccentGlow,
          borderRadius: BorderRadius.circular(radiusFull),
        ),
        child: Text('$label  $_nextCountdown s',
            style: const TextStyle(color: appAccent, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _scoreboard(List<ScoreRow> rows) {
    return ListView(
      children: rows.indexed.map((e) => AppEntrance(
        delay: Duration(milliseconds: e.$1 * 60),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: e.$2.username == _myUsername ? appAccentDim : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(radiusMd),
            border: Border.all(color: e.$1 == 0 ? appAccent.withValues(alpha: 0.5) : appDivider),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: e.$1 == 0
                    ? const Icon(Icons.emoji_events_rounded, color: appAccent, size: 18)
                    : Text('${e.$2.position}',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              UserAvatar(username: e.$2.username, avatarUrl: null, radius: 14),
              const SizedBox(width: 10),
              Expanded(
                child: Text(e.$2.username == _myUsername ? 'groups.member_you'.tr(namedArgs: {'name': '${e.$2.username}'}) : e.$2.username,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              Text('${e.$2.score}',
                  style: const TextStyle(color: appAccent, fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(width: 2),
              Text('quiz.lb_pts'.tr(),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 10)),
            ],
          ),
        ),
      )).toList(),
    );
  }

  // ── Final ───────────────────────────────────────────────────────────────────

  Widget _buildFinal() {
    final f = _finalResult!;
    final iWon = f.winner == _myUsername;
    return Padding(
      padding: const EdgeInsets.all(spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: spacingMd),
          FeedbackEntrance(
            kind: FeedbackKind.success,
            child: const Icon(Icons.emoji_events_rounded, color: appAccent, size: 56),
          ),
          const SizedBox(height: spacingSm),
          Text(iWon ? 'quiz.you_won'.tr() : 'quiz.winner_wins'.tr(namedArgs: {'user': '${f.winner ?? 'quiz.nobody'.tr()}'}),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: spacingLg),
          Expanded(child: _scoreboard(f.standings)),
          const SizedBox(height: spacingSm),
          PressableScale(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: appAccent,
                borderRadius: BorderRadius.circular(radiusMd),
              ),
              child: Center(
                child: Text('common.close'.tr(),
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _letter(int i) => const ['A', 'B', 'C', 'D'][i.clamp(0, 3)];

  String _modeLabel(String mode) => switch (mode) {
        'EMOJI'  => 'quiz.emoji_title'.tr(),
        'LYRICS' => 'quiz.lyrics_title'.tr(),
        'COVER'  => 'quiz.cover_title'.tr(),
        'AUDIO'  => 'quiz.audio_title'.tr(),
        _        => mode,
      };
}
