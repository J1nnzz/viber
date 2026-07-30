/// Constantes de los tres roles posibles dentro de una sala.
///
/// - [host]: creador de la sala; controla reproducción y modera usuarios.
/// - [dj]: puede gestionar la cola de canciones pero no play/pause/seek.
/// - [listener]: solo escucha; puede enviar chat si no está silenciado.
// ── Roles ─────────────────────────────────────────────────────────────────────
class RoomRole {
  static const String host     = 'HOST';
  static const String dj       = 'DJ';
  static const String listener = 'LISTENER';
}

// ── QueueItem ─────────────────────────────────────────────────────────────────
class QueueItem {
  final String videoId;
  final String title;
  final String thumbnail;
  final String addedBy;
  final String? channelTitle;

  const QueueItem({
    required this.videoId,
    required this.title,
    required this.thumbnail,
    required this.addedBy,
    this.channelTitle,
  });

  factory QueueItem.fromJson(Map<String, dynamic> json) => QueueItem(
        videoId:      json['videoId']      ?? '',
        title:        json['title']        ?? '',
        thumbnail:    json['thumbnail']    ?? '',
        addedBy:      json['addedBy']      ?? '',
        channelTitle: json['channelTitle'] as String?,
      );
}

// ── ChatMessage (historial desde Firestore) ───────────────────────────────────
class ChatHistoryMessage {
  final String sender;
  final String text;
  final int    timestamp; // epoch ms

  const ChatHistoryMessage({
    required this.sender,
    required this.text,
    required this.timestamp,
  });

  factory ChatHistoryMessage.fromJson(Map<String, dynamic> json) =>
      ChatHistoryMessage(
        sender:    json['sender']    as String? ?? '',
        text:      json['text']      as String? ?? '',
        timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      );

  /// Convierte al formato que usa _chatMessages en RoomScreen
  /// { 'sender': ..., 'text': ..., 'time': 'HH:MM' }
  Map<String, String> toChatEntry() {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return {'user': sender, 'text': text, 'time': time};
  }
}

// ── RoomState ─────────────────────────────────────────────────────────────────
class RoomState {
  final String? currentVideoId;
  final String? currentVideoTitle;
  final String? currentVideoThumbnail;
  final double  currentPosition;
  final bool    playing;
  final int?    lastUpdateTimestamp;

  final List<QueueItem> queue;
  final List<QueueItem> history;

  // Roles: username → "HOST" | "DJ" | "LISTENER"
  final Map<String, String> userRoles;

  // Usuarios actualmente conectados (viene del servidor en /state)
  final Set<String> onlineUsers;

  // Moderación
  final Set<String> mutedUsers;
  final Set<String> kickedUsers;

  // Historial de chat desde Firestore (últimos 50 mensajes al entrar a la sala)
  final List<ChatHistoryMessage> chatHistory;

  const RoomState({
    this.currentVideoId,
    this.currentVideoTitle,
    this.currentVideoThumbnail,
    this.currentPosition = 0.0,
    this.playing         = false,
    this.lastUpdateTimestamp,
    this.queue       = const [],
    this.history     = const [],
    this.userRoles   = const {},
    this.onlineUsers = const {},
    this.mutedUsers  = const {},
    this.kickedUsers = const {},
    this.chatHistory = const [],
  });

  // ── Helpers de rol ──────────────────────────────────────────────────────────

  String getRole(String username) =>
      userRoles[username] ?? RoomRole.listener;

  bool isHost(String username)     => getRole(username) == RoomRole.host;
  bool isDJ(String username)       => getRole(username) == RoomRole.dj;
  bool isMuted(String username)    => mutedUsers.contains(username);
  bool isKicked(String username)   => kickedUsers.contains(username);

  /// El usuario puede controlar play/pause/seek
  bool canControlPlayback(String username) => isHost(username);

  /// El usuario puede gestionar la cola (añadir/quitar/next/prev)
  bool canManageQueue(String username) =>
      isHost(username) || isDJ(username);

  // ── fromJson ────────────────────────────────────────────────────────────────

  factory RoomState.fromJson(Map<String, dynamic> json) => RoomState(
        currentVideoId:        json['currentVideoId'],
        currentVideoTitle:     json['currentVideoTitle'],
        currentVideoThumbnail: json['currentVideoThumbnail'],
        currentPosition:
            (json['currentPosition'] ?? 0).toDouble(),
        playing:             json['playing'] ?? false,
        lastUpdateTimestamp: json['lastUpdateTimestamp'],
        queue: (json['queue'] as List<dynamic>? ?? [])
            .map((e) => QueueItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        history: (json['history'] as List<dynamic>? ?? [])
            .map((e) => QueueItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        userRoles:   Map<String, String>.from(json['userRoles']   as Map? ?? {}),
        onlineUsers: Set<String>.from(json['onlineUsers'] as List? ?? []),
        mutedUsers:  Set<String>.from(json['mutedUsers']  as List? ?? []),
        kickedUsers: Set<String>.from(json['kickedUsers'] as List? ?? []),
        chatHistory: (json['chatHistory'] as List<dynamic>? ?? [])
            .map((e) => ChatHistoryMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  RoomState copyWith({
    String? currentVideoId,
    String? currentVideoTitle,
    String? currentVideoThumbnail,
    double? currentPosition,
    bool?   playing,
    int?    lastUpdateTimestamp,
    List<QueueItem>?          queue,
    List<QueueItem>?          history,
    Map<String, String>?      userRoles,
    Set<String>?              onlineUsers,
    Set<String>?              mutedUsers,
    Set<String>?              kickedUsers,
    List<ChatHistoryMessage>? chatHistory,
  }) {
    return RoomState(
      currentVideoId:        currentVideoId        ?? this.currentVideoId,
      currentVideoTitle:     currentVideoTitle     ?? this.currentVideoTitle,
      currentVideoThumbnail: currentVideoThumbnail ?? this.currentVideoThumbnail,
      currentPosition:       currentPosition       ?? this.currentPosition,
      playing:               playing               ?? this.playing,
      lastUpdateTimestamp:   lastUpdateTimestamp   ?? this.lastUpdateTimestamp,
      queue:       queue       ?? this.queue,
      history:     history     ?? this.history,
      userRoles:   userRoles   ?? this.userRoles,
      onlineUsers: onlineUsers ?? this.onlineUsers,
      mutedUsers:  mutedUsers  ?? this.mutedUsers,
      kickedUsers: kickedUsers ?? this.kickedUsers,
      chatHistory: chatHistory ?? this.chatHistory,
    );
  }

  RoomState withRoleChange(String username, String newRole) {
    final updated = Map<String, String>.from(userRoles);
    updated[username] = newRole;
    return copyWith(userRoles: updated);
  }

  RoomState withUserJoined(String username) {
    final updatedRoles  = Map<String, String>.from(userRoles);
    updatedRoles.putIfAbsent(username, () => RoomRole.listener);
    return copyWith(
      userRoles:   updatedRoles,
      onlineUsers: {...onlineUsers, username},
    );
  }

  RoomState withUserLeft(String username) {
    // Mantiene el rol, solo quita de online
    return copyWith(
      onlineUsers: onlineUsers.where((u) => u != username).toSet(),
    );
  }

  RoomState withMuted(String username) =>
      copyWith(mutedUsers: {...mutedUsers, username});

  RoomState withUnmuted(String username) =>
      copyWith(mutedUsers: mutedUsers.where((u) => u != username).toSet());

  RoomState withKicked(String username) {
    final updatedRoles = Map<String, String>.from(userRoles)..remove(username);
    return copyWith(
      userRoles:   updatedRoles,
      onlineUsers: onlineUsers.where((u) => u != username).toSet(),
      kickedUsers: {...kickedUsers, username},
    );
  }

  RoomState withUnkicked(String username) =>
      copyWith(kickedUsers: kickedUsers.where((u) => u != username).toSet());
}