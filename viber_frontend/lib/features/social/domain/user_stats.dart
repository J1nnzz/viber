class UserStats {
  final int roomsCreated;
  final int roomsJoined;
  final int totalListenSeconds;
  final List<GenreStat> topGenres;
  final List<GenreStat> topArtists;
  final int songsAdded;
  final int songsPlayed;
  final int likedSongsCount;

  const UserStats({
    required this.roomsCreated,
    required this.roomsJoined,
    required this.totalListenSeconds,
    required this.topGenres,
    required this.topArtists,
    required this.songsAdded,
    required this.songsPlayed,
    required this.likedSongsCount,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        roomsCreated: (json['roomsCreated'] as num? ?? 0).toInt(),
        roomsJoined: (json['roomsJoined'] as num? ?? 0).toInt(),
        totalListenSeconds: (json['totalListenSeconds'] as num? ?? 0).toInt(),
        topGenres: (json['topGenres'] as List<dynamic>? ?? [])
            .map((g) => GenreStat.fromJson(g as Map<String, dynamic>))
            .toList(),
        topArtists: (json['topArtists'] as List<dynamic>? ?? [])
            .map((g) => GenreStat.fromJson(g as Map<String, dynamic>))
            .toList(),
        songsAdded: (json['songsAdded'] as num? ?? 0).toInt(),
        songsPlayed: (json['songsPlayed'] as num? ?? 0).toInt(),
        likedSongsCount: (json['likedSongsCount'] as num? ?? 0).toInt(),
      );

  String get listenTimeFormatted {
    final h = totalListenSeconds ~/ 3600;
    final m = (totalListenSeconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${totalListenSeconds}s';
  }
}

class GenreStat {
  final String name;
  final int count;

  const GenreStat({required this.name, required this.count});

  factory GenreStat.fromJson(Map<String, dynamic> json) => GenreStat(
        name: json['name'] as String? ?? '',
        count: (json['count'] as num? ?? 0).toInt(),
      );
}
