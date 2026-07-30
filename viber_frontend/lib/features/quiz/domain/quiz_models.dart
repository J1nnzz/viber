// Modelos del minijuego de adivinar canciones — espejo de los DTOs del backend
// (QuizGameStateResponse y QuizSongResponse en Java).

/// Modos disponibles. El backend usa los nombres en mayúsculas ("CLASSIC").
/// Todos menos el clásico son "modos de pista": 6 intentos y una pista que
/// crece con cada fallo o salto.
enum QuizMode {
  classic,
  audio,
  lyrics,
  cover,
  emoji;

  String get apiValue => name; // los endpoints aceptan minúsculas

  bool get isClueMode => this != QuizMode.classic;

  static QuizMode fromApi(String value) => switch (value.toUpperCase()) {
        'AUDIO' => QuizMode.audio,
        'LYRICS' => QuizMode.lyrics,
        'COVER' => QuizMode.cover,
        'EMOJI' => QuizMode.emoji,
        _ => QuizMode.classic,
      };
}

/// Canción del pool tal y como aparece en el autocompletado y en los intentos.
class QuizPoolSong {
  final int id;
  final String title;
  final String artistName;
  final String? coverUrl;

  const QuizPoolSong({
    required this.id,
    required this.title,
    required this.artistName,
    this.coverUrl,
  });

  factory QuizPoolSong.fromJson(Map<String, dynamic> json) => QuizPoolSong(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String,
        artistName: json['artistName'] as String? ?? '',
        coverUrl: json['coverUrl'] as String?,
      );
}

/// Respuesta revelada al terminar la partida (incluye toda la metadata).
class QuizAnswer {
  final int id;
  final String title;
  final String artistName;
  final String? coverUrl;
  final String? videoId;
  final String? albumTitle;
  final int? releaseYear;
  final String? genre;
  final int? durationSec;
  final bool? explicit;

  const QuizAnswer({
    required this.id,
    required this.title,
    required this.artistName,
    this.coverUrl,
    this.videoId,
    this.albumTitle,
    this.releaseYear,
    this.genre,
    this.durationSec,
    this.explicit,
  });

  factory QuizAnswer.fromJson(Map<String, dynamic> json) => QuizAnswer(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String,
        artistName: json['artistName'] as String? ?? '',
        coverUrl: json['coverUrl'] as String?,
        videoId: json['videoId'] as String?,
        albumTitle: json['albumTitle'] as String?,
        releaseYear: (json['releaseYear'] as num?)?.toInt(),
        genre: json['genre'] as String?,
        durationSec: (json['durationSec'] as num?)?.toInt(),
        explicit: json['explicit'] as bool?,
      );
}

/// Una casilla de comparación del modo clásico.
/// status: CORRECT (verde) | CLOSE (amarillo) | WRONG (rojo).
/// direction: HIGHER → la respuesta es mayor que tu intento (↑), LOWER (↓).
class FieldComparison {
  final String value;
  final String status;
  final String? direction;

  const FieldComparison({
    required this.value,
    required this.status,
    this.direction,
  });

  factory FieldComparison.fromJson(Map<String, dynamic> json) => FieldComparison(
        value: json['value'] as String? ?? '?',
        status: json['status'] as String? ?? 'WRONG',
        direction: json['direction'] as String?,
      );

  bool get isCorrect => status == 'CORRECT';
  bool get isClose => status == 'CLOSE';
  bool get answerIsHigher => direction == 'HIGHER';
  bool get answerIsLower => direction == 'LOWER';
}

/// Un intento ya evaluado por el backend.
class QuizGuessResult {
  final QuizPoolSong? song; // null cuando fue un "saltar" (modo audio)
  final bool skipped;
  final bool correct;
  final bool? artistMatch; // modo audio: mismo artista aunque no sea la canción

  // Casillas del modo clásico (null en audio)
  final FieldComparison? artist;
  final FieldComparison? genre;
  final FieldComparison? year;
  final FieldComparison? duration;
  final FieldComparison? explicit;

  const QuizGuessResult({
    this.song,
    required this.skipped,
    required this.correct,
    this.artistMatch,
    this.artist,
    this.genre,
    this.year,
    this.duration,
    this.explicit,
  });

  factory QuizGuessResult.fromJson(Map<String, dynamic> json) {
    FieldComparison? field(String key) => json[key] != null
        ? FieldComparison.fromJson(json[key] as Map<String, dynamic>)
        : null;

    return QuizGuessResult(
      song: json['song'] != null
          ? QuizPoolSong.fromJson(json['song'] as Map<String, dynamic>)
          : null,
      skipped: json['skipped'] as bool? ?? false,
      correct: json['correct'] as bool? ?? false,
      artistMatch: json['artistMatch'] as bool?,
      artist: field('artist'),
      genre: field('genre'),
      year: field('year'),
      duration: field('duration'),
      explicit: field('explicit'),
    );
  }
}

/// Pistas del modo clásico: se desbloquean tras N fallos.
class QuizHints {
  final int coverUnlockAt;
  final int titleUnlockAt;
  final String? coverUrl; // null hasta desbloquear
  final String? titleHint; // "B······· R·······"

  const QuizHints({
    required this.coverUnlockAt,
    required this.titleUnlockAt,
    this.coverUrl,
    this.titleHint,
  });

  factory QuizHints.fromJson(Map<String, dynamic> json) => QuizHints(
        coverUnlockAt: (json['coverUnlockAt'] as num?)?.toInt() ?? 5,
        titleUnlockAt: (json['titleUnlockAt'] as num?)?.toInt() ?? 8,
        coverUrl: json['coverUrl'] as String?,
        titleHint: json['titleHint'] as String?,
      );
}

/// Estado completo de una partida. La respuesta solo llega cuando finished.
class QuizGameState {
  final int gameId;
  final QuizMode mode;
  final bool practice;
  final String? date; // solo diaria (yyyy-MM-dd)
  final bool finished;
  final bool solved;
  final int attemptsUsed;
  final int? maxAttempts; // 6 en modos de pista
  final int? unlockedSeconds; // audio: segundos de preview desbloqueados
  final List<int>? snippetSteps; // [1, 2, 4, 7, 12, 30]
  final List<String>? lyricsLines; // letra: líneas visibles (título censurado)
  final String? emojisVisible; // emoji: "🌧️ 🔥"
  final int? emojisTotal; // emoji: cuántos tiene en total la canción
  final QuizHints? hints;
  final List<QuizGuessResult> guesses;
  final QuizAnswer? answer;
  final int? dailySolvedCount;
  final int? pointsEarned; // puntos de ranking de esta partida (solo diaria)

  const QuizGameState({
    required this.gameId,
    required this.mode,
    required this.practice,
    this.date,
    required this.finished,
    required this.solved,
    required this.attemptsUsed,
    this.maxAttempts,
    this.unlockedSeconds,
    this.snippetSteps,
    this.lyricsLines,
    this.emojisVisible,
    this.emojisTotal,
    this.hints,
    required this.guesses,
    this.answer,
    this.dailySolvedCount,
    this.pointsEarned,
  });

  factory QuizGameState.fromJson(Map<String, dynamic> json) => QuizGameState(
        gameId: (json['gameId'] as num).toInt(),
        mode: QuizMode.fromApi(json['mode'] as String),
        practice: json['practice'] as bool? ?? false,
        date: json['date'] as String?,
        finished: json['finished'] as bool? ?? false,
        solved: json['solved'] as bool? ?? false,
        attemptsUsed: (json['attemptsUsed'] as num?)?.toInt() ?? 0,
        maxAttempts: (json['maxAttempts'] as num?)?.toInt(),
        unlockedSeconds: (json['unlockedSeconds'] as num?)?.toInt(),
        snippetSteps: (json['snippetSteps'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList(),
        lyricsLines:
            (json['lyricsLines'] as List?)?.map((e) => e as String).toList(),
        emojisVisible: json['emojisVisible'] as String?,
        emojisTotal: (json['emojisTotal'] as num?)?.toInt(),
        hints: json['hints'] != null
            ? QuizHints.fromJson(json['hints'] as Map<String, dynamic>)
            : null,
        guesses: (json['guesses'] as List? ?? [])
            .map((e) => QuizGuessResult.fromJson(e as Map<String, dynamic>))
            .toList(),
        answer: json['answer'] != null
            ? QuizAnswer.fromJson(json['answer'] as Map<String, dynamic>)
            : null,
        dailySolvedCount: (json['dailySolvedCount'] as num?)?.toInt(),
        pointsEarned: (json['pointsEarned'] as num?)?.toInt(),
      );
}

/// Estadísticas del usuario: partidas jugadas/ganadas por modo, diario y práctica.
class QuizStats {
  final Map<QuizMode, ({int played, int won})> daily;
  final Map<QuizMode, ({int played, int won})> practice;

  const QuizStats({required this.daily, required this.practice});

  factory QuizStats.fromJson(Map<String, dynamic> json) {
    Map<QuizMode, ({int played, int won})> section(String key) {
      final raw = json[key] as Map<String, dynamic>? ?? {};
      return {
        for (final mode in QuizMode.values)
          mode: (
            played: ((raw[mode.name.toUpperCase()]
                        as Map<String, dynamic>?)?['played'] as num?)
                    ?.toInt() ??
                0,
            won: ((raw[mode.name.toUpperCase()]
                        as Map<String, dynamic>?)?['won'] as num?)
                    ?.toInt() ??
                0,
          ),
      };
    }

    return QuizStats(daily: section('daily'), practice: section('practice'));
  }
}
