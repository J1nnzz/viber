import 'youtube_result.dart';

abstract class YoutubeRepository {
  Future<List<YoutubeSearchResult>> search(String query);
  Future<List<YoutubeSearchResult>> fetchPlaylist(String urlOrId, {int max = 50});
}
