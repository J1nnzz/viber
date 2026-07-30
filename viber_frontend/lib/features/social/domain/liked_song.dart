class LikedSong {
  final int id;
  final String videoId;
  final String title;
  final String? thumbnailUrl;
  final String? channelTitle;
  final DateTime likedAt;

  const LikedSong({
    required this.id,
    required this.videoId,
    required this.title,
    this.thumbnailUrl,
    this.channelTitle,
    required this.likedAt,
  });

  factory LikedSong.fromJson(Map<String, dynamic> json) => LikedSong(
        id: (json['id'] as num).toInt(),
        videoId: json['videoId'] as String,
        title: json['title'] as String,
        thumbnailUrl: json['thumbnailUrl'] as String?,
        channelTitle: json['channelTitle'] as String?,
        likedAt: DateTime.parse(json['likedAt'] as String),
      );
}
