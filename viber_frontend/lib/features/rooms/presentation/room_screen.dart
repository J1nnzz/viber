import 'dart:async';
import 'dart:convert';
import 'package:viber/features/youtube/presentation/search_song_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viber/core/constants/api_constants.dart';
import 'yt_bridge.dart';
import '../../../core/services/notification_service.dart';
import '../../auth/infrastructure/auth_service.dart';
import '../../rooms/domain/room.dart';
import '../../rooms/domain/room_message.dart';
import '../../rooms/domain/room_state.dart';
import '../../social/infrastructure/friendship_service.dart';
import '../../social/domain/user_profile.dart';
import '../infrastructure/room_service.dart';
import '../infrastructure/room_websocket_service.dart';
import 'active_room_provider.dart';
import 'edit_room_sheet.dart';
import 'widgets/iframe_pointer_events.dart';
import 'widgets/room_chat_panel.dart';
import 'widgets/room_player.dart';
import 'widgets/room_queue.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/motion.dart';

/// Pantalla principal de una sala de música colaborativa.
///
/// Gestiona de forma unificada:
///  - Conexión WebSocket STOMP (RoomWebSocketService) para recibir/enviar eventos en tiempo real.
///  - Reproductor de YouTube (YoutubePlayerIframe) sincronizado con el estado del servidor.
///  - Chat de sala, cola de canciones y controles de host/DJ.
///  - Moderación: kick, mute, cambio de rol DJ ↔ LISTENER.
///  - Minimización: al minimizar, el widget queda Offstage en AppShell y el player sigue sonando.
class RoomScreen extends StatefulWidget {
  final Room room;
  const RoomScreen({super.key, required this.room});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final AuthService _authService = AuthService();
  late RoomWebSocketService _wsService;
  late YtBridge _ytBridge;

  // ── Control del player ─────────────────────────────────────────────────────
  bool _playerInitializing = false;
  bool _playerReady        = false;
  bool _wasMinimized       = false;
  Timer? _initTimer;

  // ── Progreso ───────────────────────────────────────────────────────────────
  VoidCallback? _refreshProgress;
  double _currentSeconds = 0.0;
  double _totalSeconds   = 0.0;
  bool   _isDragging     = false;
  double _dragValue      = 0.0;
  Timer? _progressTimer;

  // ── Scroll ─────────────────────────────────────────────────────────────────
  final ScrollController _scrollController = ScrollController();

  // ── Datos de sala (actualizables por el host vía edit) ────────────────────
  late Room _room;

  // ── Estado sala ────────────────────────────────────────────────────────────
  RoomState _roomState = const RoomState();
  final List<Map<String, String>> _chatMessages = [];
  final _chatController = TextEditingController();
  final List<String> _usersInRoom = [];
  final Map<String, String?> _userAvatars = {};
  String? _username;
  bool _connected = false;
  bool _isAdmin   = false;

  // ── Permisos derivados del estado ──────────────────────────────────────────
  bool get _isHost        => _username != null && _roomState.isHost(_username!);
  bool get _isDJ          => _username != null && _roomState.isDJ(_username!);
  bool get _canControlPb  => _username != null && _roomState.canControlPlayback(_username!);
  bool get _canManageQ    => _username != null && _roomState.canManageQueue(_username!);
  bool get _isMuted       => _username != null && _roomState.isMuted(_username!);

  // ────────────────────────────────────────────────────────────────────────────
  // INIT
  // ────────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _room = widget.room;
    // Seed title/thumbnail from the room-list data so mini-player has info
    // immediately, even before _fetchInitialState() completes.
    if (widget.room.currentVideoTitle != null) {
      _roomState = RoomState(
        currentVideoTitle:     widget.room.currentVideoTitle,
        currentVideoThumbnail: widget.room.currentVideoThumbnail,
      );
    }
    _ytBridge = YtBridge();
    _init();
  }

  /// Muestra el mensaje de bienvenida de la sala una sola vez por usuario y sala
  /// (se recuerdan los IDs ya vistos en SharedPreferences).
  Future<void> _maybeShowWelcome() async {
    final msg = _room.welcomeMessage;
    if (msg == null || msg.trim().isEmpty) return;

    const key = 'viber_welcome_seen';
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getStringList(key) ?? <String>[];
      final id = _room.id.toString();
      if (seen.contains(id)) return; // ya lo vio
      seen.add(id);
      await prefs.setStringList(key, seen);
    } catch (_) {
      // Si la persistencia falla, mostramos el mensaje igualmente.
    }

    if (!mounted) return;
    final accent = hexToColorOrNull(_room.accentColor) ?? appAccent;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.waving_hand_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
        ],
      ),
      backgroundColor: accent,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd)),
    ));
  }

  Future<void> _init() async {
    final token = await _authService.getToken();
    if (token == null) return;

    final payload = jsonDecode(utf8.decode(
        base64Url.decode(base64Url.normalize(token.split('.')[1]))));
    _username = payload['sub'];

    // Detectar si el usuario es admin (para mostrar banner y omitir restricciones)
    final admin = await _authService.isAdmin();
    if (mounted) setState(() => _isAdmin = admin);

    if (!_usersInRoom.contains(_username)) _usersInRoom.add(_username!);

    await _fetchInitialState(token);

    // Sincronización inmediata con el provider para que el mini-player
    // tenga título/thumbnail aunque el usuario minimice en los primeros 500ms.
    if (mounted) _syncProvider();

    // Mensaje de bienvenida (solo la primera vez que el usuario entra a la sala).
    _maybeShowWelcome();

    _wsService = RoomWebSocketService(
      roomId:   widget.room.id,
      username: _username!,
      token:    token,
    );
    _wsService.onMessage      = _handleMessage;
    _wsService.onConnected    = () => setState(() => _connected = true);
    _wsService.onDisconnected = () => setState(() => _connected = false);

    // ── Expulsión ────────────────────────────────────────────────────────────
    _wsService.onKicked = () {
      if (!mounted) return;
      _wsService.disconnect();
      context.read<ActiveRoomProvider>().setKickedFromRoom(widget.room.name);
    };

    // ── Sala llena — entrada rechazada ───────────────────────────────────────
    _wsService.onRoomFull = () {
      if (!mounted) return;
      _wsService.disconnect();
      context.read<ActiveRoomProvider>().setRoomFull(widget.room.name);
    };

    _wsService.connect();

    // ── Registrar callback en el provider (usado por MiniPlayer) ────────────
    final provider = context.read<ActiveRoomProvider>();
    provider.onTogglePlayPause = () {
      if (_roomState.playing) {
        _sendPause();
      } else {
        _sendPlay();
      }
    };

    // ── Listener del player ──────────────────────────────────────────────────
    _ytBridge.setStateCallback((ytState) {
      if (_playerInitializing) return;
      switch (ytState) {
        case YtState.playing:
          if (!_canControlPb && !_roomState.playing) {
            _playerInitializing = true;
            _ytBridge.pause()
                .then((_) => _scheduleInitComplete(ms: 300));
          } else if (_canControlPb && !_roomState.playing) {
            _sendPlayFromIframe();
          }
          break;
        case YtState.paused:
          if (!_playerReady) return;
          if (_canControlPb && _roomState.playing) {
            _sendPauseFromIframe();
          } else if (!_canControlPb && _roomState.playing) {
            _playerInitializing = true;
            _ytBridge.play()
                .then((_) => _scheduleInitComplete(ms: 300));
          }
          break;
        case YtState.ended:
          if (_canControlPb) {
            _wsService.sendMessage(RoomMessage(
                type: RoomMessage.next, senderUsername: _username));
          }
          break;
        default:
          break;
      }
    });

    // ── Timer de progreso ────────────────────────────────────────────────────
    _progressTimer =
        Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (!mounted || _isDragging) return;

      // Detectar transición minimizado→visible.
      final nowMinimized = context.read<ActiveRoomProvider>().isMinimized;
      if (_wasMinimized && !nowMinimized) {
        // Al salir de Offstage la WebView puede emitir eventos espúreos.
        // Los suprimimos del mismo modo que al minimizar.
        _playerInitializing = true;
        _playerReady = false;
        _scheduleInitComplete(ms: 1500);

        // Seek para refrescar la posición (en web evita el iframe congelado;
        // en móvil reposiciona si la WebView perdió estado al estar oculta).
        if (!_roomState.playing && _roomState.currentVideoId != null) {
          _ytBridge.seekTo(
              _currentSeconds > 0
                  ? _currentSeconds
                  : _roomState.currentPosition,
              allowSeekAhead: false);
        }
      }
      _wasMinimized = nowMinimized;

      try {
        final t = await _ytBridge.currentTime;
        final d = await _ytBridge.duration;
        if (!mounted) return;
        if (d > 0) _totalSeconds = d;
        if (_roomState.playing && t > 0) {
          _currentSeconds = t;
          _roomState = _roomState.copyWith(currentPosition: t);
        }
        _refreshProgress?.call();
      } catch (_) {}
      // Sincronización con el provider FUERA del try/catch para que siempre
      // se ejecute aunque el player aún no esté listo (título/thumbnail).
      if (mounted) _syncProvider();
    });
  }

  void _scheduleInitComplete({int ms = 1500}) {
    _initTimer?.cancel();
    _initTimer = Timer(Duration(milliseconds: ms), () {
      if (mounted) {
        _playerInitializing = false;
        _playerReady = true;
      }
    });
  }

  void _loadVideo({
    required String videoId,
    required double startSeconds,
    required bool shouldPlay,
  }) {
    _playerInitializing = true;
    _playerReady = false;
    if (shouldPlay) {
      _ytBridge
          .loadVideo(videoId, startAt: startSeconds, autoPlay: true)
          .then((_) => _scheduleInitComplete(ms: 2000));
    } else {
      _ytBridge
          .loadVideo(videoId, startAt: startSeconds, autoPlay: false)
          .then((_) => _scheduleInitComplete(ms: 500));
    }
  }

  Future<void> _fetchInitialState(String token) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.roomsUrl}/${widget.room.id}/state'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final state = RoomState.fromJson(jsonDecode(res.body));

        if (_username != null && state.isKicked(_username!)) {
          if (mounted) {
            Navigator.of(context).pop('kicked:${widget.room.name}');
          }
          return;
        }

        setState(() {
          _roomState = state;
          _usersInRoom
            ..clear()
            ..addAll(state.onlineUsers);
          if (_username != null && !_usersInRoom.contains(_username)) {
            _usersInRoom.add(_username!);
          }
          if (state.chatHistory.isNotEmpty) {
            _chatMessages
              ..clear()
              ..addAll(state.chatHistory.map((m) => m.toChatEntry()));
          }
        });

        if (state.currentVideoId != null) {
          _currentSeconds = state.currentPosition;
          _loadVideo(
            videoId:      state.currentVideoId!,
            startSeconds: state.currentPosition,
            shouldPlay:   state.playing,
          );
        } else {
          _playerInitializing = false;
          _playerReady = true;
        }
      }
    } catch (e) {
      debugPrint('Error fetching room state: $e');
      _playerInitializing = false;
      _playerReady = true;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // HANDLE MESSAGES
  // ────────────────────────────────────────────────────────────────────────────

  void _handleMessage(RoomMessage msg) {
    setState(() {
      _onMessage(msg);
    });
    if (mounted) _syncProvider();
    // Cachear avatar del remitente en background
    if (msg.senderUsername != null) _cacheAvatar(msg.senderUsername!);
  }

  Future<void> _cacheAvatar(String username) async {
    if (_userAvatars.containsKey(username)) return;
    _userAvatars[username] = null; // marca "en proceso" para no refetch
    try {
      final profile = await FriendshipService().getProfile(username);
      if (mounted) setState(() => _userAvatars[username] = profile.avatarUrl);
    } catch (_) {}
  }

  void _onMessage(RoomMessage msg) {
      switch (msg.type) {
        case RoomMessage.play:
          final newId     = msg.videoId ?? _roomState.currentVideoId;
          final needsLoad = newId != null && newId != _roomState.currentVideoId;
          _roomState = _roomState.copyWith(
            currentVideoId:        newId,
            currentVideoTitle:     msg.videoTitle,
            currentVideoThumbnail: msg.videoThumbnail,
            currentPosition:       msg.position ?? 0.0,
            playing:               true,
            lastUpdateTimestamp:   msg.serverTimestamp,
          );
          _currentSeconds = msg.position ?? 0.0;
          _refreshProgress?.call();
          if (needsLoad) {
            _totalSeconds = 0.0;
            _loadVideo(videoId: newId!, startSeconds: msg.position ?? 0.0, shouldPlay: true);
          } else {
            _playerInitializing = true;
            _ytBridge
                .seekTo(msg.position ?? 0.0, allowSeekAhead: true)
                .then((_) => _ytBridge.play())
                .then((_) => _scheduleInitComplete(ms: 800));
          }

        case RoomMessage.pause:
          _roomState = _roomState.copyWith(
            currentPosition:     msg.position ?? _roomState.currentPosition,
            playing:             false,
            lastUpdateTimestamp: msg.serverTimestamp,
          );
          _currentSeconds = msg.position ?? _currentSeconds;
          _refreshProgress?.call();
          _playerInitializing = true;
          _ytBridge.pause()
              .then((_) => _scheduleInitComplete(ms: 300));

        case RoomMessage.seek:
          _roomState = _roomState.copyWith(
            currentPosition: msg.position ?? _roomState.currentPosition,
          );
          _currentSeconds = msg.position ?? _currentSeconds;
          _refreshProgress?.call();
          if (_playerReady) {
            _playerInitializing = true;
            _ytBridge
                .seekTo(msg.position ?? 0, allowSeekAhead: true)
                .then((_) => _scheduleInitComplete(ms: 500));
          }

        case RoomMessage.next:
          if (_roomState.queue.isNotEmpty) {
            final next = _roomState.queue.first;
            _roomState = _roomState.copyWith(
              currentVideoId:        next.videoId,
              currentVideoTitle:     next.title,
              currentVideoThumbnail: next.thumbnail,
              currentPosition: 0.0,
              playing:         true,
              history: [
                ..._roomState.history,
                if (_roomState.currentVideoId != null)
                  QueueItem(
                    videoId:   _roomState.currentVideoId!,
                    title:     _roomState.currentVideoTitle ?? '',
                    thumbnail: _roomState.currentVideoThumbnail ?? '',
                    addedBy:   '',
                  ),
              ],
              queue: _roomState.queue.skip(1).toList(),
            );
            _currentSeconds = 0.0;
            _totalSeconds   = 0.0;
            _refreshProgress?.call();
            _loadVideo(videoId: next.videoId, startSeconds: 0.0, shouldPlay: true);
          }

        case RoomMessage.prev:
          if (_roomState.history.isNotEmpty) {
            final prev = _roomState.history.last;
            _roomState = _roomState.copyWith(
              currentVideoId:        prev.videoId,
              currentVideoTitle:     prev.title,
              currentVideoThumbnail: prev.thumbnail,
              currentPosition:       0.0,
              playing:          true,
              history: _roomState.history
                  .take(_roomState.history.length - 1)
                  .toList(),
              queue: [
                if (_roomState.currentVideoId != null)
                  QueueItem(
                    videoId:   _roomState.currentVideoId!,
                    title:     _roomState.currentVideoTitle ?? '',
                    thumbnail: _roomState.currentVideoThumbnail ?? '',
                    addedBy:   '',
                  ),
                ..._roomState.queue,
              ],
            );
            _currentSeconds = 0.0;
            _totalSeconds   = 0.0;
            _refreshProgress?.call();
            _loadVideo(videoId: prev.videoId, startSeconds: 0.0, shouldPlay: true);
          }

        case RoomMessage.queueAdd:
          _roomState = _roomState.copyWith(queue: [
            ..._roomState.queue,
            QueueItem(
              videoId:   msg.videoId   ?? '',
              title:     msg.videoTitle     ?? '',
              thumbnail: msg.videoThumbnail ?? '',
              addedBy:   msg.senderUsername ?? '',
            ),
          ]);

        case RoomMessage.queueRemove:
          final idx = msg.queueIndex;
          if (idx != null && idx >= 0 && idx < _roomState.queue.length) {
            final updated = List<QueueItem>.from(_roomState.queue)..removeAt(idx);
            _roomState = _roomState.copyWith(queue: updated);
          }

        case RoomMessage.queueMove:
          final from = msg.queueIndex;
          final to   = msg.targetIndex;
          if (from != null && to != null &&
              from >= 0 && from < _roomState.queue.length &&
              to   >= 0 && to   < _roomState.queue.length &&
              from != to) {
            final updated = List<QueueItem>.from(_roomState.queue);
            final item = updated.removeAt(from);
            updated.insert(to, item);
            _roomState = _roomState.copyWith(queue: updated);
          }

        case RoomMessage.roleChange:
          final target  = msg.targetUsername;
          final newRole = msg.role;
          if (target != null && newRole != null) {
            _roomState = _roomState.withRoleChange(target, newRole);
            if (target == _username) {
              final label = newRole == RoomRole.dj ? 'DJ' : 'Oyente';
              _showCompactSnackbar(
                'Tu rol ha cambiado a $label',
                color: newRole == RoomRole.dj ? appAccent : null,
              );
            }
            _chatMessages.add({
              'user': 'system',
              'text': '$target ahora es ${newRole == RoomRole.dj ? "DJ" : "Oyente"}',
              'time': _timeNow(),
            });
          }

        case RoomMessage.userKicked:
          final target = msg.targetUsername;
          if (target != null) {
            _roomState = _roomState.withKicked(target);
            _usersInRoom.remove(target);
            _chatMessages.add({
              'user': 'system',
              'text': '$target fue expulsado de la sala',
              'time': _timeNow(),
            });
          }

        case RoomMessage.userUnkicked:
          final target = msg.targetUsername;
          if (target != null) {
            _roomState = _roomState.withUnkicked(target);
            _chatMessages.add({
              'user': 'system',
              'text': 'El ban de $target ha sido levantado',
              'time': _timeNow(),
            });
          }

        case RoomMessage.userMuted:
          final target = msg.targetUsername;
          if (target != null) {
            _roomState = _roomState.withMuted(target);
            _chatMessages.add({
              'user': 'system',
              'text': '$target fue silenciado',
              'time': _timeNow(),
            });
            if (target == _username) {
              _showCompactSnackbar('Has sido silenciado', color: appError);
            }
          }

        case RoomMessage.userUnmuted:
          final target = msg.targetUsername;
          if (target != null) {
            _roomState = _roomState.withUnmuted(target);
            _chatMessages.add({
              'user': 'system',
              'text': '$target ya puede hablar de nuevo',
              'time': _timeNow(),
            });
            if (target == _username) {
              _showCompactSnackbar('Ya puedes enviar mensajes', color: appSuccess);
            }
          }

        case RoomMessage.userJoined:
          if (msg.senderUsername != null &&
              !_usersInRoom.contains(msg.senderUsername)) {
            _usersInRoom.add(msg.senderUsername!);
          }
          if (msg.senderUsername != null) {
            _roomState = _roomState.withUserJoined(msg.senderUsername!);
          }
          _chatMessages.add({
            'user': 'system',
            'text': '${msg.senderUsername} entró a la sala',
            'time': _timeNow(),
          });

        case RoomMessage.userLeft:
          _usersInRoom.remove(msg.senderUsername);
          if (msg.senderUsername != null) {
            _roomState = _roomState.withUserLeft(msg.senderUsername!);
          }
          _chatMessages.add({
            'user': 'system',
            'text': '${msg.senderUsername} salió de la sala',
            'time': _timeNow(),
          });

        case RoomMessage.chat:
          final chatContent = msg.content ?? '';
          _chatMessages.add({
            'user': msg.senderUsername ?? 'Anónimo',
            'text': chatContent,
            'time': _timeNow(),
          });
          // Sonido de mención si alguien nos etiqueta y no somos nosotros
          if (_username != null &&
              msg.senderUsername != _username &&
              RegExp(
                '@${RegExp.escape(_username!)}\\b',
                caseSensitive: false,
              ).hasMatch(chatContent)) {
            NotificationService.playMentionSound();
          }

        case RoomMessage.roomClosed:
          // El host ha cerrado la sala — salir sin confirmación
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _wsService.disconnect();
            context.read<ActiveRoomProvider>().setRoomClosedByHost(_room.name);
          });
      }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // SEND
  // ────────────────────────────────────────────────────────────────────────────

  void _sendPlay() => _wsService.sendMessage(RoomMessage(
      type:           RoomMessage.play,
      senderUsername: _username,
      videoId:        _roomState.currentVideoId,
      position:       _roomState.currentPosition));

  void _sendPause() async {
    double pos = _currentSeconds > 0
        ? _currentSeconds
        : _roomState.currentPosition;
    try {
      final t = await _ytBridge.currentTime;
      if (t > 0) pos = t;
    } catch (_) {}
    _wsService.sendMessage(RoomMessage(
        type: RoomMessage.pause, senderUsername: _username, position: pos));
  }

  void _sendPlayFromIframe() async {
    double pos = _currentSeconds > 0
        ? _currentSeconds
        : _roomState.currentPosition;
    try {
      final t = await _ytBridge.currentTime;
      if (t > 0) pos = t;
    } catch (_) {}
    _wsService.sendMessage(RoomMessage(
        type:           RoomMessage.play,
        senderUsername: _username,
        videoId:        _roomState.currentVideoId,
        position:       pos));
  }

  void _sendPauseFromIframe() {
    final pos = _currentSeconds > 0
        ? _currentSeconds
        : _roomState.currentPosition;
    _wsService.sendMessage(RoomMessage(
        type: RoomMessage.pause, senderUsername: _username, position: pos));
  }

  void _sendChat() {
    if (_chatController.text.trim().isEmpty) return;
    if (_isMuted) {
      _showCompactSnackbar('Estás silenciado', color: appError);
      return;
    }
    _wsService.sendMessage(RoomMessage(
        type:           RoomMessage.chat,
        senderUsername: _username,
        content:        _chatController.text.trim()));
    _chatController.clear();
  }

  void _sendQueueRemove(int index) {
    _wsService.sendMessage(RoomMessage(
      type:           RoomMessage.queueRemove,
      senderUsername: _username,
      queueIndex:     index,
    ));
  }

  void _sendQueueMove(int from, int to) {
    if (from == to) return;
    _wsService.sendMessage(RoomMessage(
      type:           RoomMessage.queueMove,
      senderUsername: _username,
      queueIndex:     from,
      targetIndex:    to,
    ));
  }

  String _timeNow() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:'
        '${n.minute.toString().padLeft(2, '0')}';
  }

  void _showCompactSnackbar(String text, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontSize: 13)),
        backgroundColor: color ?? context.appSurfaceAltColor,
        behavior:  SnackBarBehavior.floating,
        width:     280,
        duration:  const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
    );
  }

  void _syncProvider() {
    context.read<ActiveRoomProvider>().updatePlayback(
      roomState:       _roomState,
      playing:         _roomState.playing,
      connected:       _connected,
      listenerCount:   _usersInRoom.length,
      currentSeconds:  _currentSeconds,
      totalSeconds:    _totalSeconds,
      currentUsername: _username,
    );
  }

  // AppShell pone RoomScreen en Offstage+IgnorePointer → player sigue vivo.
  void _minimize() {
    // Al pasar a Offstage la WebView puede emitir un evento "paused" espúreo.
    // Suprimimos callbacks del player durante 1.5 s para que el host no envíe
    // accidentalmente un PAUSE al servidor y deje a todos los oyentes sin música.
    _playerInitializing = true;
    _playerReady = false;
    _scheduleInitComplete(ms: 1500);

    _syncProvider(); // empujar estado actual antes de que el mini-player sea visible
    context.read<ActiveRoomProvider>().minimize();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _initTimer?.cancel();
    _wsService.disconnect();
    _ytBridge.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      backgroundColor: context.appBgColor,
      appBar: _buildTopBar(),
      body: Column(
        children: [
          if (_isAdmin) _buildAdminBanner(),
          Expanded(child: isWide ? _buildWide() : _buildNarrow()),
        ],
      ),
    );
  }

  // ── Banner "Modo administrador" ──────────────────────────────────────────────
  Widget _buildAdminBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: Colors.orange.shade800,
      child: const Row(
        children: [
          Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 14),
          SizedBox(width: 6),
          Text(
            'Modo administrador · Solo observando',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Diálogo de reporte ────────────────────────────────────────────────────────
  Future<void> _openReportDialog() async {
    final ctrl = TextEditingController();
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.flag_outlined, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Text('Reportar sala', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Describe el problema que has detectado en esta sala.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Ej. Contenido inapropiado, comportamiento abusivo…',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Enviar reporte'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    final reason = ctrl.text.trim();
    ctrl.dispose();
    if (sent != true || reason.isEmpty || !mounted) return;

    try {
      await RoomService().reportRoom(roomId: _room.id, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Reporte enviado. El equipo de moderación lo revisará.'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  PreferredSizeWidget _buildTopBar() {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return PreferredSize(
      preferredSize: Size.fromHeight(56 + statusBarHeight),
      child: SafeArea(
        bottom: false,
        child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: context.appSurfaceColor,
          border: Border(bottom: BorderSide(color: appDivider)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // ── Minimizar ───────────────────────────────────────────────────
            IconButton(
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  color: context.appTextSecColor, size: 24),
              tooltip: 'Minimizar',
              onPressed: _minimize,
            ),
            const SizedBox(width: 4),
            // ── Título y género ─────────────────────────────────────────────
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_room.name,
                      style: TextStyle(
                          color: context.appTextPrimColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2)),
                  if (_room.genres.isNotEmpty)
                    Text(
                      _room.genres.join(' · '),
                      style: TextStyle(
                          color: context.appTextSecColor, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // ── Contador oyentes ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: appEnergyGlow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: appEnergy.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people_outline, color: appEnergy, size: 14),
                  const SizedBox(width: 5),
                  Text('${_usersInRoom.length}',
                      style: const TextStyle(
                          color: appEnergy,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // ── Indicador conexión (late cuando está conectado) ─────────────
            _connected
                ? const LiveDot(size: 8, color: appSuccess)
                : Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                    ),
                  ),
            // ── Invitar ─────────────────────────────────────────────────────
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_rounded,
                  color: appAccent, size: 20),
              tooltip: 'Invitar a la sala',
              onPressed: _openInviteSheet,
            ),
            // ── Reportar sala ───────────────────────────────────────────────
            if (!_isHost && !_isAdmin)
              IconButton(
                icon: Icon(Icons.flag_outlined,
                    color: context.appTextSecColor, size: 18),
                tooltip: 'Reportar sala',
                onPressed: _openReportDialog,
              ),
            // ── Ajustes (solo host) ─────────────────────────────────────────
            if (_isHost)
              IconButton(
                icon: Icon(Icons.settings_rounded,
                    color: context.appTextSecColor, size: 18),
                tooltip: 'Gestionar sala',
                onPressed: _openRoomSettings,
              ),
            // ── Salir definitivamente ───────────────────────────────────────
            IconButton(
              icon: Icon(Icons.logout_rounded,
                  color: context.appTextSecColor, size: 18),
              tooltip: 'Salir de la sala',
              onPressed: () => _confirmLeave(),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _confirmLeave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Salir de la sala?'),
        content: const Text('Perderás la sincronización con los demás.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salir',
                  style: TextStyle(color: appError))),
        ],
      ),
    );
    // provider.leaveRoom() → _room = null → AppShell elimina RoomScreen → dispose()
    if (ok == true && mounted) {
      context.read<ActiveRoomProvider>().leaveRoom();
    }
  }

  Widget _buildWide() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Scrollbar(
            controller: _scrollController,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildPlayerWithScrollFix(),
                  const SizedBox(height: 16),
                  RoomQueue(
                    queue:          _roomState.queue,
                    canManageQueue: _canManageQ,
                    onAddSong:      _openSearchSheet,
                    onRemove:       _sendQueueRemove,
                    onMove:         _sendQueueMove,
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(width: 1, color: appDivider),
        SizedBox(
          width: 320,
          child: RoomChatPanel(
            messages:        _chatMessages,
            users:           _usersInRoom,
            currentUsername: _username,
            hostUsername:    _room.hostUsername,
            userRoles:       _roomState.userRoles,
            mutedUsers:      _roomState.mutedUsers,
            userAvatars:     _userAvatars,
            chatController:  _chatController,
            onSend:          _sendChat,
            isHost:          _isHost,
            kickedUsers:     _roomState.kickedUsers,
            onPromoteDJ:     (u) => _wsService.promoteToDJ(u),
            onDemote:        (u) => _wsService.demoteToListener(u),
            onKick:          (u) => _wsService.kickUser(u),
            onUnkick:        (u) => _wsService.unkickUser(u),
            onMute:          (u) => _wsService.muteUser(u),
            onUnmute:        (u) => _wsService.unmuteUser(u),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrow() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildPlayerWithScrollFix(),
                const SizedBox(height: 16),
                RoomQueue(
                  queue:          _roomState.queue,
                  canManageQueue: _canManageQ,
                  onAddSong:      _openSearchSheet,
                  onRemove:       _sendQueueRemove,
                  onMove:         _sendQueueMove,
                ),
              ],
            ),
          ),
        ),
        Divider(color: appDivider, height: 1),
        SizedBox(
          height: 380,
          child: RoomChatPanel(
            messages:        _chatMessages,
            users:           _usersInRoom,
            currentUsername: _username,
            hostUsername:    _room.hostUsername,
            userRoles:       _roomState.userRoles,
            mutedUsers:      _roomState.mutedUsers,
            userAvatars:     _userAvatars,
            chatController:  _chatController,
            onSend:          _sendChat,
            isHost:          _isHost,
            kickedUsers:     _roomState.kickedUsers,
            onPromoteDJ:     (u) => _wsService.promoteToDJ(u),
            onDemote:        (u) => _wsService.demoteToListener(u),
            onKick:          (u) => _wsService.kickUser(u),
            onUnkick:        (u) => _wsService.unkickUser(u),
            onMute:          (u) => _wsService.muteUser(u),
            onUnmute:        (u) => _wsService.unmuteUser(u),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerWithScrollFix() {
    return StatefulBuilder(builder: (context, setPlayerSt) {
      _refreshProgress = () => setPlayerSt(() {});

      return RoomPlayer(
        ytBridge:              _ytBridge,
        currentVideoId:        _roomState.currentVideoId,
        currentVideoTitle:     _roomState.currentVideoTitle,
        currentVideoThumbnail: _roomState.currentVideoThumbnail,
        playing:               _roomState.playing,
        isHost:           _canControlPb,
        currentSeconds:   _currentSeconds,
        totalSeconds:     _totalSeconds,
        isDragging:       _isDragging,
        dragValue:        _dragValue,
        scrollController: _scrollController,
        hasNext:          _roomState.queue.isNotEmpty,
        hasPrev:          _roomState.history.isNotEmpty,
        onPlay:           _sendPlay,
        onPause:          _sendPause,
        onNext: () => _wsService.sendMessage(
            RoomMessage(type: RoomMessage.next, senderUsername: _username)),
        onPrev: () => _wsService.sendMessage(
            RoomMessage(type: RoomMessage.prev, senderUsername: _username)),
        onSeekStart: (v) => setPlayerSt(() {
          _isDragging = true;
          _dragValue  = v;
        }),
        onSeekChanged: (v) => setPlayerSt(() => _dragValue = v),
        onSeekEnd: (v) {
          setPlayerSt(() {
            _isDragging     = false;
            _currentSeconds = v;
          });
          _roomState = _roomState.copyWith(currentPosition: v);
          _wsService.sendMessage(RoomMessage(
              type: RoomMessage.seek, senderUsername: _username, position: v));
        },
      );
    });
  }

  void _openSearchSheet() {
    setIframePointerEvents(enable: false);
    showAddMenu(
      context:   context,
      wsService: _wsService,
      username:  _username ?? '',
    ).whenComplete(() => setIframePointerEvents(enable: true));
  }

  void _openInviteSheet() {
    setIframePointerEvents(enable: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InviteSheet(
        room:            _room,
        currentUsername: _username,
      ),
    ).whenComplete(() => setIframePointerEvents(enable: true));
  }

  Future<void> _openRoomSettings() async {
    setIframePointerEvents(enable: false);
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditRoomSheet(room: _room),
    );
    setIframePointerEvents(enable: true);

    if (!mounted) return;

    if (result == EditRoomSheet.kClosed) {
      // Host cerró la sala → salir
      context.read<ActiveRoomProvider>().leaveRoom();
    } else if (result is Room) {
      // Datos actualizados → refrescar UI
      setState(() => _room = result);
    }
  }
}

// ── Invite Sheet ─────────────────────────────────────────────────────────────

class _InviteSheet extends StatefulWidget {
  final Room room;
  final String? currentUsername;

  const _InviteSheet({required this.room, this.currentUsername});

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _friendService = FriendshipService();
  List<UserProfile> _friends = [];
  bool _loading = true;
  final Set<String> _inviting = {};
  final Set<String> _invited  = {};

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      final friends = await _friendService.getFriends();
      if (mounted) setState(() => _friends = friends);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _invite(String username) async {
    setState(() => _inviting.add(username));
    try {
      await _friendService.inviteFriend(username, widget.room.id);
      if (mounted) setState(() => _invited.add(username));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: appError,
        ));
      }
    } finally {
      if (mounted) setState(() => _inviting.remove(username));
    }
  }

  Widget _buildFriendAvatar(UserProfile friend) {
    const double radius = 18;
    final initial = friend.displayLabel.isNotEmpty
        ? friend.displayLabel[0].toUpperCase()
        : '?';
    final fallbackChild = Text(
      initial,
      style: const TextStyle(
          color: appAccent, fontSize: 13, fontWeight: FontWeight.w700),
    );
    if (friend.avatarUrl == null || friend.avatarUrl!.isEmpty) {
      return CircleAvatar(
          radius: radius,
          backgroundColor: appAccentGlow,
          child: fallbackChild);
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: appAccentGlow,
      child: ClipOval(
        child: AppImage(
          url: friend.avatarUrl!,
          width: radius * 2,
          height: radius * 2,
          errorBuilder: (_) => fallbackChild,
        ),
      ),
    );
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Código copiado al portapapeles'),
          ],
        ),
        backgroundColor: appSuccess,
        behavior: SnackBarBehavior.floating,
        width: 280,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPrivate  = widget.room.isPrivate;
    final accessCode = widget.room.accessCode;
    final bottomPad  = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: context.appSurfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle ────────────────────────────────────────────────────────
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: context.appDividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Título ────────────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.person_add_alt_1_rounded,
                  color: appAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Invitar a "${widget.room.name}"',
                  style: TextStyle(
                    color: context.appTextPrimColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Código de sala ────────────────────────────────────────────────
          if (isPrivate && accessCode != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: appAccentGlow,
                borderRadius: BorderRadius.circular(radiusMd),
                border: Border.all(color: appAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.vpn_key_rounded,
                      color: appAccent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Código de acceso',
                          style: TextStyle(
                            color: context.appTextSecColor,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          accessCode,
                          style: const TextStyle(
                            color: appAccent,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded,
                        color: appAccent, size: 18),
                    tooltip: 'Copiar código',
                    onPressed: () => _copyCode(accessCode),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Comparte este código para que otros puedan unirse',
                style: TextStyle(color: context.appTextDimColor, fontSize: 11),
              ),
            ),
            const SizedBox(height: 16),
          ] else if (!isPrivate) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: context.appCard2Color,
                borderRadius: BorderRadius.circular(radiusMd),
                border: Border.all(color: appDivider),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_open_rounded,
                      color: context.appTextSecColor, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Sala pública — cualquiera puede unirse',
                    style: TextStyle(color: context.appTextSecColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Sección amigos ────────────────────────────────────────────────
          Text(
            'Invitar amigos',
            style: TextStyle(
              color: context.appTextSecColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                  child: CircularProgressIndicator(
                      color: appAccent, strokeWidth: 2)),
            )
          else if (_friends.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.people_outline,
                        color: context.appTextDimColor, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      'No tienes amigos aún.\nAñade amigos desde la pestaña Amigos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.appTextDimColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _friends.length,
                itemBuilder: (_, i) {
                  final friend   = _friends[i];
                  final isSelf   = friend.username == widget.currentUsername;
                  final sent     = _invited.contains(friend.username);
                  final sending  = _inviting.contains(friend.username);

                  if (isSelf) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        // Avatar
                        _buildFriendAvatar(friend),
                        const SizedBox(width: 10),
                        // Nombre
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                friend.displayLabel,
                                style: TextStyle(
                                  color: context.appTextPrimColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '@${friend.username}',
                                style: TextStyle(
                                    color: context.appTextDimColor, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        // Botón invitar
                        if (sent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: appSuccess.withOpacity(0.15),
                              borderRadius:
                                  BorderRadius.circular(radiusFull),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_rounded,
                                    color: appSuccess, size: 14),
                                SizedBox(width: 4),
                                Text('Enviado',
                                    style: TextStyle(
                                        color: appSuccess,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          )
                        else
                          SizedBox(
                            height: 32,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: appAccent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(radiusFull),
                                ),
                              ),
                              icon: sending
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: Colors.white),
                                    )
                                  : const Icon(Icons.send_rounded, size: 13),
                              label: Text(
                                sending ? 'Enviando...' : 'Invitar',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                              onPressed: sending
                                  ? null
                                  : () => _invite(friend.username),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}