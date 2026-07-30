import '../domain/leaderboard_models.dart';
import '../domain/quiz_models.dart';
import '../domain/quiz_repository.dart';

/// Casos de uso del quiz — misma estructura que youtube_use_cases.dart.

class SearchQuizSongsUseCase {
  final QuizRepository _repository;
  SearchQuizSongsUseCase(this._repository);
  Future<List<QuizPoolSong>> call(String query, QuizMode mode) =>
      _repository.searchSongs(query, mode);
}

class GetDailyQuizGameUseCase {
  final QuizRepository _repository;
  GetDailyQuizGameUseCase(this._repository);
  Future<QuizGameState> call(QuizMode mode) => _repository.getDailyGame(mode);
}

class NewPracticeQuizGameUseCase {
  final QuizRepository _repository;
  NewPracticeQuizGameUseCase(this._repository);
  Future<QuizGameState> call(QuizMode mode) => _repository.newPracticeGame(mode);
}

class GuessQuizSongUseCase {
  final QuizRepository _repository;
  GuessQuizSongUseCase(this._repository);
  Future<QuizGameState> call(int gameId, int songId) =>
      _repository.guess(gameId, songId);
}

class SkipQuizTurnUseCase {
  final QuizRepository _repository;
  SkipQuizTurnUseCase(this._repository);
  Future<QuizGameState> call(int gameId) => _repository.skip(gameId);
}

class SurrenderQuizGameUseCase {
  final QuizRepository _repository;
  SurrenderQuizGameUseCase(this._repository);
  Future<QuizGameState> call(int gameId) => _repository.surrender(gameId);
}

class GetQuizStatsUseCase {
  final QuizRepository _repository;
  GetQuizStatsUseCase(this._repository);
  Future<QuizStats> call() => _repository.getStats();
}

class GetQuizLeaderboardUseCase {
  final QuizRepository _repository;
  GetQuizLeaderboardUseCase(this._repository);
  Future<Leaderboard> call(LeaderboardScope scope, LeaderboardPeriod period) =>
      _repository.getLeaderboard(scope, period);
}
