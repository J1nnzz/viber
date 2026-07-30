/// Resultado de búsqueda o elemento de playlist de YouTube.
/// Devuelto por /api/youtube/search y /api/youtube/playlist.
class YoutubeSearchResult {
  final String videoId;
  final String title;
  final String thumbnail;
  final String channel;

  const YoutubeSearchResult({
    required this.videoId,
    required this.title,
    required this.thumbnail,
    required this.channel,
  });

  factory YoutubeSearchResult.fromJson(Map<String, dynamic> j) =>
      YoutubeSearchResult(
        videoId:   j['videoId']   as String? ?? '',
        title:     j['title']     as String? ?? '',
        thumbnail: j['thumbnail'] as String? ?? '',
        channel:   j['channel']   as String? ?? '',
      );
}
