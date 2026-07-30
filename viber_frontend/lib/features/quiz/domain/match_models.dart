/// Modelos del quiz EN VIVO (competición tipo Kahoot).
///
/// Reflejan los payloads STOMP que emite QuizMatchService en el backend
/// (LOBBY / QUESTION / REVEAL / FINAL) y la invitación personal (INVITE).

/// Invitación a una partida que llega por `/user/queue/quizmatch`.
class MatchInvite {
  final int     matchId;
  final String  mode;
  final String  scope;        // DM | GROUP
  final int?    groupId;
  final String  from;
  final int     totalRounds;
  final int     secondsPerRound;

  const MatchInvite({
    required this.matchId,
    required this.mode,
    required this.scope,
    this.groupId,
    required this.from,
    required this.totalRounds,
    required this.secondsPerRound,
  });

  factory MatchInvite.fromJson(Map<String, dynamic> j) => MatchInvite(
        matchId:         (j['matchId'] as num).toInt(),
        mode:            j['mode'] as String? ?? 'EMOJI',
        scope:           j['scope'] as String? ?? 'DM',
        groupId:         (j['groupId'] as num?)?.toInt(),
        from:            j['from'] as String? ?? '',
        totalRounds:     (j['totalRounds'] as num?)?.toInt() ?? 0,
        secondsPerRound: (j['secondsPerRound'] as num?)?.toInt() ?? 0,
      );
}

class LobbyState {
  final int     matchId;
  final String  host;
  final String  mode;
  final String  scope;
  final int     totalRounds;
  final int     secondsPerRound;
  final List<String> players;
  final String  status;       // LOBBY | RUNNING | FINISHED

  const LobbyState({
    required this.matchId,
    required this.host,
    required this.mode,
    required this.scope,
    required this.totalRounds,
    required this.secondsPerRound,
    required this.players,
    required this.status,
  });

  factory LobbyState.fromJson(Map<String, dynamic> j) => LobbyState(
        matchId:         (j['matchId'] as num?)?.toInt() ?? 0,
        host:            j['host'] as String? ?? '',
        mode:            j['mode'] as String? ?? 'EMOJI',
        scope:           j['scope'] as String? ?? 'DM',
        totalRounds:     (j['totalRounds'] as num?)?.toInt() ?? 0,
        secondsPerRound: (j['secondsPerRound'] as num?)?.toInt() ?? 0,
        players:         (j['players'] as List?)?.map((e) => e as String).toList() ?? const [],
        status:          j['status'] as String? ?? 'LOBBY',
      );
}

class MatchOption {
  final int    id;
  final String title;
  final String artist;
  const MatchOption({required this.id, required this.title, required this.artist});

  factory MatchOption.fromJson(Map<String, dynamic> j) => MatchOption(
        id:     (j['id'] as num).toInt(),
        title:  j['title'] as String? ?? '',
        artist: j['artist'] as String? ?? '',
      );
}

class QuestionEvent {
  final int    round;
  final int    totalRounds;
  final String mode;
  final String? clueText;
  final String? clueImageUrl;
  final bool   clueAudio;     // true en modo AUDIO: el cliente pide el preview por proxy
  final List<MatchOption> options;
  final int    endsAt;        // epoch ms (reloj del servidor)
  final int    serverNow;     // epoch ms (reloj del servidor al emitir)

  const QuestionEvent({
    required this.round,
    required this.totalRounds,
    required this.mode,
    this.clueText,
    this.clueImageUrl,
    this.clueAudio = false,
    required this.options,
    required this.endsAt,
    required this.serverNow,
  });

  /// Segundos restantes estimados desde la recepción del evento.
  int get secondsLeft =>
      ((endsAt - serverNow) / 1000).ceil().clamp(0, 60);

  factory QuestionEvent.fromJson(Map<String, dynamic> j) => QuestionEvent(
        round:       (j['round'] as num?)?.toInt() ?? 0,
        totalRounds: (j['totalRounds'] as num?)?.toInt() ?? 0,
        mode:        j['mode'] as String? ?? 'EMOJI',
        clueText:     j['clueText'] as String?,
        clueImageUrl: j['clueImageUrl'] as String?,
        clueAudio:    j['clueAudio'] as bool? ?? false,
        options: (j['options'] as List?)
                ?.map((e) => MatchOption.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        endsAt:    (j['endsAt'] as num?)?.toInt() ?? 0,
        serverNow: (j['serverNow'] as num?)?.toInt() ?? 0,
      );
}

class ScoreRow {
  final int    position;
  final String username;
  final int    score;
  final int    correctCount;
  const ScoreRow({
    required this.position,
    required this.username,
    required this.score,
    required this.correctCount,
  });

  factory ScoreRow.fromJson(Map<String, dynamic> j) => ScoreRow(
        position:     (j['position'] as num?)?.toInt() ?? 0,
        username:     j['username'] as String? ?? '',
        score:        (j['score'] as num?)?.toInt() ?? 0,
        correctCount: (j['correctCount'] as num?)?.toInt() ?? 0,
      );
}

class RevealEvent {
  final int    round;
  final int    correctOptionId;
  final String correctTitle;
  final String correctArtist;
  final String? correctCoverUrl;
  final List<ScoreRow> scoreboard;
  final int    nextInSeconds;   // segundos hasta la siguiente ronda / resultados
  final bool   last;            // true si era la última ronda

  const RevealEvent({
    required this.round,
    required this.correctOptionId,
    required this.correctTitle,
    required this.correctArtist,
    this.correctCoverUrl,
    required this.scoreboard,
    this.nextInSeconds = 4,
    this.last = false,
  });

  factory RevealEvent.fromJson(Map<String, dynamic> j) {
    final correct = (j['correct'] as Map<String, dynamic>?) ?? const {};
    return RevealEvent(
      round:           (j['round'] as num?)?.toInt() ?? 0,
      correctOptionId: (j['correctOptionId'] as num?)?.toInt() ?? 0,
      correctTitle:    correct['title'] as String? ?? '',
      correctArtist:   correct['artist'] as String? ?? '',
      correctCoverUrl: correct['coverUrl'] as String?,
      scoreboard: (j['scoreboard'] as List?)
              ?.map((e) => ScoreRow.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      nextInSeconds: (j['nextInSeconds'] as num?)?.toInt() ?? 4,
      last:          j['last'] as bool? ?? false,
    );
  }
}

class FinalEvent {
  final List<ScoreRow> standings;
  final String? winner;
  const FinalEvent({required this.standings, this.winner});

  factory FinalEvent.fromJson(Map<String, dynamic> j) => FinalEvent(
        winner: j['winner'] as String?,
        standings: (j['standings'] as List?)
                ?.map((e) => ScoreRow.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}
