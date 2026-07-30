// Modelos del leaderboard del quiz — espejo de LeaderboardResponse (Java).
// Solo puntúa el reto diario; la práctica no entra. Dos ejes: ámbito
// (mundial/amigos) y periodo (diario/mes).

/// Ámbito del ranking.
enum LeaderboardScope {
  world,
  friends;

  String get apiValue => name;
}

/// Ventana temporal del ranking.
/// - diario: el día de hoy (tablero "en directo", se mueve hasta que todos
///   completan sus modos).
/// - mes: lo que va de mes (clasificación estable del periodo largo).
enum LeaderboardPeriod {
  daily,
  month;

  String get apiValue => name;
}

/// Una fila del ranking (un usuario agregado en la ventana consultada).
class LeaderboardRow {
  final int rank;
  final int userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final int points;
  final int solvedCount;
  final bool isMe;

  const LeaderboardRow({
    required this.rank,
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.points,
    required this.solvedCount,
    required this.isMe,
  });

  /// Nombre a mostrar: el display name si lo hay, si no el username.
  String get name => (displayName != null && displayName!.trim().isNotEmpty)
      ? displayName!
      : username;

  factory LeaderboardRow.fromJson(Map<String, dynamic> json) => LeaderboardRow(
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        userId: (json['userId'] as num).toInt(),
        username: json['username'] as String? ?? '',
        displayName: json['displayName'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        points: (json['points'] as num?)?.toInt() ?? 0,
        solvedCount: (json['solvedCount'] as num?)?.toInt() ?? 0,
        isMe: json['me'] as bool? ?? false,
      );
}

/// Resumen del propio usuario: su posición en la ventana + su racha (global).
class LeaderboardMe {
  final int? rank; // null si está fuera del top mostrado o no ha jugado
  final bool ranked; // false si no tiene partidas puntuadas en la ventana
  final int points;
  final int solvedCount;
  final int currentStreak;
  final int bestStreak;

  const LeaderboardMe({
    this.rank,
    required this.ranked,
    required this.points,
    required this.solvedCount,
    required this.currentStreak,
    required this.bestStreak,
  });

  factory LeaderboardMe.fromJson(Map<String, dynamic> json) => LeaderboardMe(
        rank: (json['rank'] as num?)?.toInt(),
        ranked: json['ranked'] as bool? ?? false,
        points: (json['points'] as num?)?.toInt() ?? 0,
        solvedCount: (json['solvedCount'] as num?)?.toInt() ?? 0,
        currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
        bestStreak: (json['bestStreak'] as num?)?.toInt() ?? 0,
      );
}

/// Ranking completo devuelto por el backend.
class Leaderboard {
  final LeaderboardScope scope;
  final LeaderboardPeriod period;
  final List<LeaderboardRow> entries;
  final LeaderboardMe me;

  const Leaderboard({
    required this.scope,
    required this.period,
    required this.entries,
    required this.me,
  });

  factory Leaderboard.fromJson(Map<String, dynamic> json) => Leaderboard(
        scope: (json['scope'] as String?) == 'friends'
            ? LeaderboardScope.friends
            : LeaderboardScope.world,
        period: (json['period'] as String?) == 'month'
            ? LeaderboardPeriod.month
            : LeaderboardPeriod.daily,
        entries: (json['entries'] as List? ?? [])
            .map((e) => LeaderboardRow.fromJson(e as Map<String, dynamic>))
            .toList(),
        me: LeaderboardMe.fromJson(
            (json['me'] as Map<String, dynamic>?) ?? const {}),
      );
}
