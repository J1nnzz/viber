import '../domain/youtube_result.dart';
import '../domain/youtube_repository.dart';

class SearchYoutubeUseCase {
  final YoutubeRepository _repository;
  SearchYoutubeUseCase(this._repository);
  Future<List<YoutubeSearchResult>> call(String query) =>
      _repository.search(query);
}

class FetchPlaylistUseCase {
  final YoutubeRepository _repository;
  FetchPlaylistUseCase(this._repository);
  Future<List<YoutubeSearchResult>> call(String urlOrId, {int max = 50}) =>
      _repository.fetchPlaylist(urlOrId, max: max);
}
