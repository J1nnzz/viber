/// Mensaje intercambiado por WebSocket entre el cliente y el servidor en una sala.
///
/// Se serializa/deserializa a JSON para el protocolo STOMP.
/// Los campos relevantes dependen del [type] del mensaje:
///  - Reproducción: videoId, position, serverTimestamp
///  - Cola: videoId, videoTitle, videoThumbnail, queueIndex, targetIndex
///  - Moderación/roles: targetUsername, role
///  - Chat: content
class RoomMessage {
  /// Tipos de mensaje soportados por el protocolo WebSocket de sala.
  static const String play        = 'PLAY';
  static const String pause       = 'PAUSE';
  static const String seek        = 'SEEK';
  static const String next        = 'NEXT';
  static const String prev        = 'PREV';
  static const String queueAdd    = 'QUEUE_ADD';
  static const String queueRemove = 'QUEUE_REMOVE';
  static const String queueMove   = 'QUEUE_MOVE';
  static const String userJoined  = 'USER_JOINED';
  static const String userLeft    = 'USER_LEFT';
  static const String chat        = 'CHAT';
  // Moderación y roles
  static const String roleChange  = 'ROLE_CHANGE';
  static const String userKicked   = 'USER_KICKED';
  static const String userUnkicked = 'USER_UNKICKED';
  static const String userMuted    = 'USER_MUTED';
  static const String userUnmuted  = 'USER_UNMUTED';
  static const String roomClosed   = 'ROOM_CLOSED';

  final String  type;
  final String? senderUsername;

  // Reproductor
  final String? videoId;
  final String? videoTitle;
  final String? videoThumbnail;
  final double? position;
  final int?    serverTimestamp;

  // Cola
  final String? videoChannel; // canal/artista de YouTube — presente en QUEUE_ADD
  final int? queueIndex;      // índice origen (QUEUE_REMOVE, QUEUE_MOVE)
  final int? targetIndex;     // índice destino (QUEUE_MOVE)

  // Moderación / roles
  /// Usuario sobre el que actúa la acción (kick, mute, role change)
  final String? targetUsername;
  /// Nuevo rol asignado en ROLE_CHANGE: "DJ" | "LISTENER"
  final String? role;

  // Chat
  final String? content;

  const RoomMessage({
    required this.type,
    this.senderUsername,
    this.videoId,
    this.videoTitle,
    this.videoThumbnail,
    this.videoChannel,
    this.position,
    this.serverTimestamp,
    this.queueIndex,
    this.targetIndex,
    this.targetUsername,
    this.role,
    this.content,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    if (senderUsername  != null) 'senderUsername':  senderUsername,
    if (videoId         != null) 'videoId':         videoId,
    if (videoTitle      != null) 'videoTitle':      videoTitle,
    if (videoThumbnail  != null) 'videoThumbnail':  videoThumbnail,
    if (videoChannel    != null) 'videoChannel':    videoChannel,
    if (position        != null) 'position':        position,
    if (queueIndex      != null) 'queueIndex':      queueIndex,
    if (targetIndex     != null) 'targetIndex':     targetIndex,
    if (targetUsername  != null) 'targetUsername':  targetUsername,
    if (role            != null) 'role':            role,
    if (content         != null) 'content':         content,
  };

  factory RoomMessage.fromJson(Map<String, dynamic> json) => RoomMessage(
    type:            json['type'],
    senderUsername:  json['senderUsername'],
    videoId:         json['videoId'],
    videoTitle:      json['videoTitle'],
    videoThumbnail:  json['videoThumbnail'],
    videoChannel:    json['videoChannel'],
    position:        (json['position'] as num?)?.toDouble(),
    serverTimestamp: json['serverTimestamp'],
    queueIndex:      json['queueIndex'],
    targetIndex:     json['targetIndex'],
    targetUsername:  json['targetUsername'],
    role:            json['role'],
    content:         json['content'],
  );
}