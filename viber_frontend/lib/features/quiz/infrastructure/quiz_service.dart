import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:viber/core/constants/api_constants.dart';
import '../../../core/services/base_api_service.dart';
import '../domain/leaderboard_models.dart';
import '../domain/quiz_models.dart';
import '../domain/quiz_repository.dart';

/// Cliente HTTP del quiz (/api/quiz). El backend nunca expone la canción
/// secreta hasta terminar la partida: aquí solo viajan intentos y casillas.
class QuizService extends BaseApiService implements QuizRepository {
  // ── Autocompletado ────────────────────────────────────────────────────────

  @override
  Future<List<QuizPoolSong>> searchSongs(String query, QuizMode mode) async {
    final uri = Uri.parse('${ApiConstants.quizUrl}/songs/search').replace(
      queryParameters: {'q': query, 'mode': mode.apiValue},
    );
    final res = await http.get(uri, headers: await authHeaders());
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((e) => QuizPoolSong.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throwFromResponse(res, 'errors.song_search'.tr());
  }

  // ── Partidas ──────────────────────────────────────────────────────────────

  @override
  Future<QuizGameState> getDailyGame(QuizMode mode) =>
      _getState('${ApiConstants.quizUrl}/daily/${mode.apiValue}');

  @override
  Future<QuizGameState> getGame(int gameId) =>
      _getState('${ApiConstants.quizUrl}/games/$gameId');

  @override
  Future<QuizGameState> newPracticeGame(QuizMode mode) =>
      _postState('${ApiConstants.quizUrl}/practice/${mode.apiValue}');

  @override
  Future<QuizGameState> guess(int gameId, int songId) => _postState(
        '${ApiConstants.quizUrl}/games/$gameId/guess',
        body: {'songId': songId},
      );

  @override
  Future<QuizGameState> skip(int gameId) =>
      _postState('${ApiConstants.quizUrl}/games/$gameId/skip');

  @override
  Future<QuizGameState> surrender(int gameId) =>
      _postState('${ApiConstants.quizUrl}/games/$gameId/surrender');

  // ── Audio ─────────────────────────────────────────────────────────────────

  @override
  Future<String> audioUrl(int gameId) async {
    final token = await getToken();
    return '${ApiConstants.quizUrl}/games/$gameId/audio?token=$token';
  }

  @override
  Future<String> coverUrl(int gameId) async {
    final token = await getToken();
    return '${ApiConstants.quizUrl}/games/$gameId/cover?token=$token';
  }

  // ── Estadísticas ──────────────────────────────────────────────────────────

  @override
  Future<QuizStats> getStats() async {
    final res = await http.get(
      Uri.parse('${ApiConstants.quizUrl}/stats'),
      headers: await authHeaders(),
    );
    if (res.statusCode == 200) {
      return QuizStats.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throwFromResponse(res, 'errors.quiz_stats_load'.tr());
  }

  // ── Leaderboard ─────────────────────────────────────────────────────────────

  @override
  Future<Leaderboard> getLeaderboard(
      LeaderboardScope scope, LeaderboardPeriod period) async {
    final uri = Uri.parse('${ApiConstants.quizUrl}/leaderboard').replace(
      queryParameters: {'scope': scope.apiValue, 'period': period.apiValue},
    );
    final res = await http.get(uri, headers: await authHeaders());
    if (res.statusCode == 200) {
      return Leaderboard.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throwFromResponse(res, 'errors.leaderboard_load'.tr());
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<QuizGameState> _getState(String url) async {
    final res = await http.get(Uri.parse(url), headers: await authHeaders());
    if (res.statusCode == 200) {
      return QuizGameState.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throwFromResponse(res, 'errors.match_load'.tr());
  }

  Future<QuizGameState> _postState(String url, {Map<String, dynamic>? body}) async {
    final res = await http.post(
      Uri.parse(url),
      headers: await authHeaders(),
      body: body != null ? jsonEncode(body) : null,
    );
    if (res.statusCode == 200) {
      return QuizGameState.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throwFromResponse(res, 'errors.guess_failed'.tr());
  }
}
