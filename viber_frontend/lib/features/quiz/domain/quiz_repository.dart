import 'leaderboard_models.dart';
import 'quiz_models.dart';

/// Contrato de acceso al quiz — implementado por QuizService (infrastructure).
abstract class QuizRepository {
  /// Autocompletado de intentos contra el pool propio (nunca contra YouTube).
  Future<List<QuizPoolSong>> searchSongs(String query, QuizMode mode);

  /// Partida diaria del usuario para un modo (el backend la crea si no existe).
  Future<QuizGameState> getDailyGame(QuizMode mode);

  /// Nueva partida de práctica con canción aleatoria (modo infinito).
  Future<QuizGameState> newPracticeGame(QuizMode mode);

  /// Estado actual de una partida.
  Future<QuizGameState> getGame(int gameId);

  /// Intentar adivinar; devuelve el estado actualizado con las casillas.
  Future<QuizGameState> guess(int gameId, int songId);

  /// Saltar turno en modo audio (desbloquea más segundos).
  Future<QuizGameState> skip(int gameId);

  /// Rendirse y revelar la respuesta.
  Future<QuizGameState> surrender(int gameId);

  /// URL del preview MP3 servido por el backend (incluye el JWT como query
  /// param porque el elemento de audio del navegador no puede mandar headers).
  Future<String> audioUrl(int gameId);

  /// URL de la portada pixelada por el backend (modo portada). El nivel de
  /// pixelado lo decide el servidor según los intentos gastados.
  Future<String> coverUrl(int gameId);

  /// Estadísticas del usuario.
  Future<QuizStats> getStats();

  /// Clasificación del quiz para un ámbito (mundial/amigos) y periodo
  /// (diario/mes). Solo cuenta el reto diario.
  Future<Leaderboard> getLeaderboard(
      LeaderboardScope scope, LeaderboardPeriod period);
}
