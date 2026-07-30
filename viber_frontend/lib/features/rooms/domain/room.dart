/// Modelo de sala de música en el cliente Flutter.
/// Refleja los campos del DTO RoomResponse del backend.
/// Los campos de reproducción ([currentVideoTitle], [currentVideoThumbnail], [listenerCount])
/// vienen del estado en tiempo real del servidor y pueden ser null si la sala está vacía.
class Room {
  final int id;
  final String name;
  final String? description;
  final List<String> genres;
  final String privacy;
  final String hostUsername;
  final String createdAt;
  final bool active;
  final bool autoDj;
  final int? maxParticipants;
  final String? accessCode;

  // Personalización de la sala (null = valores por defecto de la app)
  final String? coverImageUrl;
  final String? accentColor;
  final String? welcomeMessage;

  // Datos de reproducción en tiempo real (null si no hay nada sonando)
  final String? currentVideoTitle;
  final String? currentVideoThumbnail;
  final int listenerCount;

  Room({
    required this.id,
    required this.name,
    this.description,
    this.genres = const [],
    required this.privacy,
    required this.hostUsername,
    required this.createdAt,
    required this.active,
    this.autoDj = false,
    this.maxParticipants,
    this.accessCode,
    this.coverImageUrl,
    this.accentColor,
    this.welcomeMessage,
    this.currentVideoTitle,
    this.currentVideoThumbnail,
    this.listenerCount = 0,
  });

  bool get isPrivate => privacy.toUpperCase() == 'PRIVATE';
  bool get hasCurrentTrack => currentVideoTitle != null && currentVideoTitle!.isNotEmpty;

  Room copyWith({
    String? name,
    String? description,
    List<String>? genres,
    String? privacy,
    String? accessCode,
    int? maxParticipants,
    bool? autoDj,
    String? coverImageUrl,
    String? accentColor,
    String? welcomeMessage,
    String? currentVideoTitle,
    String? currentVideoThumbnail,
    int? listenerCount,
  }) {
    return Room(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      genres: genres ?? this.genres,
      privacy: privacy ?? this.privacy,
      hostUsername: hostUsername,
      createdAt: createdAt,
      active: active,
      autoDj: autoDj ?? this.autoDj,
      accessCode: accessCode ?? this.accessCode,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      accentColor: accentColor ?? this.accentColor,
      welcomeMessage: welcomeMessage ?? this.welcomeMessage,
      currentVideoTitle: currentVideoTitle ?? this.currentVideoTitle,
      currentVideoThumbnail: currentVideoThumbnail ?? this.currentVideoThumbnail,
      listenerCount: listenerCount ?? this.listenerCount,
    );
  }

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      genres: (json['genres'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      privacy: json['privacy'],
      hostUsername: json['hostUsername'],
      createdAt: json['createdAt'],
      active: json['active'],
      autoDj: json['autoDj'] as bool? ?? false,
      maxParticipants: json['maxParticipants'] as int?,
      accessCode: json['accessCode'] as String?,
      coverImageUrl: json['coverImageUrl'] as String?,
      accentColor: json['accentColor'] as String?,
      welcomeMessage: json['welcomeMessage'] as String?,
      currentVideoTitle: json['currentVideoTitle'] as String?,
      currentVideoThumbnail: json['currentVideoThumbnail'] as String?,
      listenerCount: (json['listenerCount'] as num?)?.toInt() ?? 0,
    );
  }
}
